import App
import DatabaseClient
import DependenciesTestSupport
import EnvVars
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(
  .dependencies {
    $0.date.now = Date(timeIntervalSince1970: 1_709_251_200)
    $0.uuid = .incrementing
  })
struct EquivalentLengthAuthorizationTests {
  @Test
  func routesEnforceOwnershipAndPathMembership() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .warning
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let database = DatabaseClient.live(database: app.db)
      let owner = try await database.users.create(
        .init(
          email: "owner@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let other = try await database.users.create(
        .init(
          email: "other@example.test", password: "super-secret", confirmPassword: "super-secret"))
      let project = try await database.projects.create(
        owner.id,
        .init(
          name: "Private project", streetAddress: "1 Test St", city: "Cincinnati", state: "OH",
          zipCode: "45202"))
      let otherProject = try await database.projects.create(
        other.id,
        .init(
          name: "Other project", streetAddress: "2 Test St", city: "Cincinnati", state: "OH",
          zipCode: "45202"))
      let path = try await database.equivalentLengths.create(
        .init(
          projectID: project.id, name: "Private path", type: .supply, straightLengths: [10],
          groups: []))
      let client = try app.testing()
      let login = try await client.sendRequest(
        .POST, "/login",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: .init(string: "email=other%40example.test&password=super-secret"))
      let cookie = try #require(login.headers.first(name: .setCookie)).split(separator: ";")[0]
      let headers: HTTPHeaders = [
        "Cookie": String(cookie), "Content-Type": "application/x-www-form-urlencoded",
      ]
      for projectID in [project.id, otherProject.id] {
        let base = "/projects/\(projectID)/effective-lengths"
        for (method, url) in [
          (HTTPMethod.DELETE, "\(base)/\(path.id)"), (.GET, "\(base)/\(path.id)/duplicate"),
          (.GET, "\(base)/editor?id=\(path.id)"),
        ] {
          let response = try await client.sendRequest(method, url, headers: headers)
          #expect(!response.body.string.contains("Private path"))
          #expect(try await database.equivalentLengths.get(path.id) == path)
        }
      }
      let base = "/projects/\(project.id)/effective-lengths"
      for url in [base, base + "/editor", base + "/guided"] {
        let response = try await client.sendRequest(.GET, url, headers: headers)
        #expect(response.status == .notFound || response.body.string.contains("unavailable"))
        #expect(!response.body.string.contains("Private path"))
      }
      for url in [
        "/projects/\(project.id)", "/projects/\(project.id)/pdf",
        "/projects/\(project.id)/friction-rate",
      ] {
        let response = try await client.sendRequest(.GET, url, headers: headers)
        #expect(response.status == .notFound)
      }
      let deletion = try await client.sendRequest(
        .DELETE, "/projects/\(project.id)", headers: headers)
      #expect(deletion.status == .notFound)
      #expect(try await database.equivalentLengths.get(path.id) == path)

    }
  }
}
