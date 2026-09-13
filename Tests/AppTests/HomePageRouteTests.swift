import App
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct HomePageRouteTests {
  @Test func publicHomeAndReadOnlySamples() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .warning
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let client = try app.testing()
      let home = try await client.sendRequest(.GET, "/")
      #expect(home.status == .ok)
      #expect(home.headers.first(name: .cacheControl) == "private, no-store")
      #expect(home.headers.first(name: .vary) == "Cookie, HX-Request")
      #expect(home.body.string.contains("Your next duct design,"))
      #expect(home.body.string.contains("href=\"/signup\""))
      #expect(home.body.string.contains("href=\"/login\""))
      #expect(!home.body.string.contains("noindex"))
      #expect(home.body.readableBytes < 15_000)

      for step in HomePreviewStep.allCases {
        let preview = try await client.sendRequest(.GET, "/home-preview/\(step.rawValue)")
        #expect(preview.status == .ok)
        #expect(preview.body.string.contains("noindex, nofollow"))
        #expect(preview.body.string.contains("<div inert=\"\""))
        #expect(preview.body.string.contains("Maple Avenue"))
        #expect(!preview.body.string.contains("<script"))
      }
      for path in ["/home-preview/unknown", "/landing-prototypes", "/icon-prototypes"] {
        let response = try await client.sendRequest(.GET, path)
        #expect(response.status == .notFound)
      }
      let post = try await client.sendRequest(.POST, "/home-preview/rooms")
      #expect(post.status == .notFound || post.status == .methodNotAllowed)
    }
  }
}
