import App
import CSVParser
import DatabaseClient
import Dependencies
import Foundation
import ManualDCore
import PdfImportClient
import Testing
import VaporTesting

@Suite(.serialized)
struct RoomPDFUploadTests {
  @Test
  func rejectsMalformedBodiesWithoutCrashing() async throws {
    try await withApp { app in
      try await configure(app, in: .init())
      try await app.autoMigrate()
      // These fail during routing, before authentication. Wrong upload paths must never
      // send malformed binary data into URLRouting.FormData's unchecked array indexing.
      for path in [
        "/projects", "/projects/00000000-0000-0000-0000-000000000000/rooms/unknown", "/signup",
      ] {
        for contentType in [
          "application/x-www-form-urlencoded", "multipart/form-data; boundary=test",
        ] {
          try await app.testing().test(
            .POST, path, headers: ["Content-Type": contentType], body: ByteBuffer(string: "&%ZZ")
          ) { response in
            #expect(response.status == .notFound)
          }
        }
      }
      try await app.testing().test(.GET, "/health") { #expect($0.status == .ok) }
    }
  }

  @Test
  func uploadsRequireAuthentication() async throws {
    try await withApp { app in
      try await configure(app, in: .init())
      try await app.autoMigrate()
      app.environment = .development
      for path in [
        "/projects/import/pdf", "/projects/00000000-0000-0000-0000-000000000000/rooms/pdf",
      ] {
        try await app.testing().test(
          .POST, path,
          headers: ["Content-Type": "multipart/form-data; boundary=test"],
          body: ByteBuffer(string: "--test--\r\n")
        ) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers.first(name: .location)?.hasPrefix("/login") == true)
        }
      }
    }
  }

  @Test
  func multipartUploadCreatesProject() async throws {
    try await uploadProject(file: Data("%PDF-\0&%ZZ".utf8), useLiveParser: false, expectedRooms: 1)
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["COOL_CALC_REFERENCE_PDF"] != nil))
  func originalPDFCreatesProjectThroughHTTP() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["COOL_CALC_REFERENCE_PDF"])
    try await uploadProject(
      file: Data(contentsOf: URL(fileURLWithPath: path)), useLiveParser: true, expectedRooms: 17)
  }

  private func uploadProject(file: Data, useLiveParser: Bool, expectedRooms: Int) async throws {
    try await withDependencies {
      if useLiveParser {
        $0.pdfImport = .liveValue
      } else {
        $0.pdfImport.parseProject = { pdf in
          #expect(pdf.file == file)
          return .init(
            project: .mock, rooms: [.init(name: "Dining", heatingLoad: 3846, coolingTotal: 1668)])
        }
      }
    } operation: {
      try await withApp { app in
        try await configure(app, in: .init())
        try await app.autoMigrate()
        let database = DatabaseClient.live(database: app.db)
        let user = try await database.users.create(
          .init(
            email: "project-pdf@example.com", password: "super-secret",
            confirmPassword: "super-secret"))
        app.middleware.use(LoggedInUser(user: user), at: .beginning)
        let boundary = "project-pdf-test-boundary"
        var body = ByteBuffer()
        body.writeString(
          "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"report.pdf\"\r\nContent-Type: application/pdf\r\n\r\n"
        )
        body.writeBytes(file)
        body.writeString("\r\n--\(boundary)--\r\n")
        try await app.testing().test(
          .POST, "/projects/import/pdf",
          headers: [
            "Content-Type": "multipart/form-data; boundary=\(boundary)", "HX-Request": "true",
          ], body: body
        ) { response in
          #expect(response.status == .ok)
          #expect(response.body.string.contains("Dining"))
          #expect(!response.body.string.contains("Oops: Error"))
        }
        let projects = try await database.projects.fetch(user.id, .first)
        #expect(projects.items.count == 1)
        let project = try #require(projects.items.first)
        #expect(
          !project.name.isEmpty && !project.streetAddress.isEmpty && !project.city.isEmpty
            && !project.state.isEmpty && !project.zipCode.isEmpty)
        #expect(project.sensibleHeatRatio == (useLiveParser ? 0.88 : 0.83))
        #expect(try await database.rooms.fetch(project.id).count == expectedRooms)
        #expect(try await !database.componentLosses.fetch(project.id).isEmpty)
        if !useLiveParser {
          #expect(project.streetAddress == Project.Create.mock.streetAddress)
        }
        // The repeated upload returns a warning and creates nothing until confirmed.
        try await app.testing().test(
          .POST, "/projects/import/pdf",
          headers: [
            "Content-Type": "multipart/form-data; boundary=\(boundary)", "HX-Request": "true",
          ], body: body
        ) { response in
          #expect(response.status == .ok)
          #expect(response.body.string.contains("data-project-import-conflict"))
          #expect(response.body.string.contains("Possible duplicate project"))
        }
        #expect(try await database.projects.fetch(user.id, .first).items.count == 1)
        var confirmed = ByteBuffer()
        confirmed.writeString(
          "--\(boundary)\r\nContent-Disposition: form-data; name=\"confirmDuplicate\"\r\n\r\ntrue\r\n"
        )
        confirmed.writeBytes(body.readableBytesView)
        try await app.testing().test(
          .POST, "/projects/import/pdf",
          headers: [
            "Content-Type": "multipart/form-data; boundary=\(boundary)", "HX-Request": "true",
          ], body: confirmed
        ) { response in
          #expect(response.status == .ok)
          #expect(!response.body.string.contains("data-project-import-conflict"))
          #expect(response.body.string.contains("Dining"))
        }
        #expect(try await database.projects.fetch(user.id, .first).items.count == 2)
        #expect(try await database.projects.get(project.id) == project)
        #expect(try await database.rooms.fetch(project.id).count == expectedRooms)

      }
    }
  }

  @Test
  func csvUploadCreatesRooms() async throws {
    // No trailing newline: the multipart boundary must never become part of the CSV row.
    let file = Data(
      "Name,Level,Heating Load,Cooling Total,Cooling Sensible,Register Count,Delegated To\nDining,1,3846,1668,,1,"
        .utf8)
    try await upload(file: file, expectedCount: 1, useLiveParser: false, format: "csv")
  }

  @Test
  func multipartUploadCreatesRooms() async throws {
    // Include binary bytes and line endings to catch accidental UTF-8 or multipart-envelope parsing.
    // A bare ampersand followed by an invalid percent escape crashes URLRouting's
    // FormData parser if an unrelated route inspects the PDF body.
    let file = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0xFF, 0x0D, 0x0A]) + Data("&%ZZ".utf8)
    try await upload(file: file, expectedCount: 1, useLiveParser: false)
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["COOL_CALC_REFERENCE_PDF"] != nil))
  func originalPDFThroughHTTP() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["COOL_CALC_REFERENCE_PDF"])
    try await upload(
      file: Data(contentsOf: URL(fileURLWithPath: path)), expectedCount: 17, useLiveParser: true)
  }

  private func upload(file: Data, expectedCount: Int, useLiveParser: Bool, format: String = "pdf")
    async throws
  {
    try await withDependencies {
      $0.csvParser = .liveValue
      if useLiveParser {
        $0.pdfImport = .liveValue
      } else {
        $0.pdfImport.parseRooms = { pdf in
          #expect(pdf.file == file)
          return .init(
            rooms: [.init(name: "Dining", level: 1, heatingLoad: 3846, coolingTotal: 1668)],
            sensibleHeatRatio: 0.88)
        }
      }
    } operation: {
      try await withApp { app in
        try await configure(app, in: .init())
        try await app.autoMigrate()
        let database = DatabaseClient.live(database: app.db)
        let user = try await database.users.create(
          .init(email: "pdf@example.com", password: "super-secret", confirmPassword: "super-secret")
        )
        let project = try await database.projects.create(user.id, .mock)
        app.middleware.use(LoggedInUser(user: user), at: .beginning)

        let route =
          SiteRoute.router.path(for: .view(.project(.detail(project.id, .rooms(.index))))) + "/"
          + format
        let boundary = "room-pdf-test-boundary"
        var body = ByteBuffer()
        body.writeString(
          "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"report.\(format)\"\r\nContent-Type: \(format == "csv" ? "text/csv" : "application/pdf")\r\n\r\n"
        )
        body.writeBytes(file)
        body.writeString("\r\n--\(boundary)--\r\n")
        try await app.testing().test(
          .POST, route,
          headers: [
            "Content-Type": "multipart/form-data; boundary=\(boundary)", "HX-Request": "true",
          ],
          body: body
        ) { response in
          #expect(response.status == .ok)
          #expect(response.body.string.contains("Dining"))
          #expect(!response.body.string.contains("Oops: Error"))
        }
        let rooms = try await database.rooms.fetch(project.id)
        #expect(rooms.count == expectedCount)
        let dining = try #require(rooms.first { $0.name == "Dining" })
        #expect(dining.coolingLoad.total == 1668)
        #expect(dining.coolingLoad.sensible == nil)

        // Re-upload after deleting one room: add it back and update the others in place.
        let deleted = try #require(rooms.first)
        try await database.rooms.delete(deleted.id)
        try await app.testing().test(
          .POST, route,
          headers: [
            "Content-Type": "multipart/form-data; boundary=\(boundary)", "HX-Request": "true",
          ],
          body: body
        ) { response in
          #expect(response.status == .ok)
          #expect(!response.body.string.contains("Oops: Error"))
          #expect(response.body.string.contains("hx-confirm=\"This project already has rooms."))
        }
        let restored = try await database.rooms.fetch(project.id)
        #expect(restored.count == expectedCount)
        for room in rooms where room.id != deleted.id {
          #expect(restored.first { $0.name == room.name }?.id == room.id)
        }
      }
    }
  }
}

private struct LoggedInUser: AsyncMiddleware {
  let user: User

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    request.auth.login(user)
    return try await next.respond(to: request)
  }
}
