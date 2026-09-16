import App
import DependenciesTestSupport
import Foundation
import ManualDCore
import Testing
import VaporTesting

@Suite(.dependencies { $0.context = .live })
struct HomePageRouteTests {
  @Test func publicSearchMetadata() async throws {
    try await withApp(configure: { app in
      app.logger.logLevel = .warning
      try await configure(app, in: .live())
      try await app.autoMigrate()
    }) { app in
      let client = try app.testing()
      for (path, canonicalPath, title, description) in [
        (
          "/", "/", "Residential HVAC Duct Design Software | DuctCalc", "Import CoolCalc room loads"
        ),
        (
          "/ductulator", "/ductulator", "Duct Sizing Calculator / Ductulator | DuctCalc",
          "Calculate round and rectangular duct sizes"
        ),
        (
          "/fittings?system=return&group=8", "/fittings",
          "Duct Fitting Equivalent Length Reference | DuctCalc", "Browse duct fitting drawings"
        ),
      ] {
        let response = try await client.sendRequest(.GET, path)
        #expect(response.status == .ok)
        let html = response.body.string
        #expect(html.contains("<title>\(title)</title>"))
        #expect(html.contains("rel=\"canonical\" href=\"https://ductcalc.pro\(canonicalPath)\""))
        #expect(html.contains("property=\"og:title\" content=\"\(title)\""))
        #expect(
          html.contains("property=\"og:url\" content=\"https://ductcalc.pro\(canonicalPath)\""))
        #expect(html.contains(description))
        #expect(!html.contains("name=\"keywords\""))
        #expect(!html.contains("noindex"))
      }

      let sitemap = try await client.sendRequest(.GET, "/sitemap.xml")
      #expect(sitemap.status == .ok)
      #expect(sitemap.headers.contentType == .xml)
      let locations = sitemap.body.string.components(separatedBy: "<loc>").dropFirst()
        .compactMap { $0.components(separatedBy: "</loc>").first }
      #expect(
        locations == [
          "https://ductcalc.pro/", "https://ductcalc.pro/ductulator",
          "https://ductcalc.pro/fittings",
        ])
      let robots = try await client.sendRequest(.GET, "/robots.txt")
      #expect(robots.status == .ok)
      #expect(robots.body.string.contains("Sitemap: https://ductcalc.pro/sitemap.xml"))

      let login = try await client.sendRequest(.GET, "/login")
      #expect(!login.body.string.contains("rel=\"canonical\""))
    }
  }

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
      #expect(home.body.string.contains("The speed sheet"))
      #expect(home.body.string.contains("href=\"/signup\""))
      #expect(home.body.string.contains("href=\"/login\""))
      #expect(!home.body.string.contains("noindex"))
      #expect(home.body.readableBytes < 25_000)

      for step in HomePreviewStep.allCases {
        let preview = try await client.sendRequest(.GET, "/home-preview/\(step.rawValue)")
        #expect(preview.status == .ok)
        #expect(preview.body.string.contains("noindex, nofollow"))
        #expect(preview.body.string.contains("<div inert=\"\""))
        #expect(preview.body.string.contains("Maple Avenue"))
        #expect(!preview.body.string.contains("<script"))
      }
      for path in [
        "/home-preview/unknown", "/landing-prototypes", "/icon-prototypes",
        "/home-concepts/editorial", "/home-concepts/studio", "/home-concepts/walkthrough",
      ] {
        let response = try await client.sendRequest(.GET, path)
        #expect(response.status == .notFound)
      }
      let post = try await client.sendRequest(.POST, "/home-preview/rooms")
      #expect(post.status == .notFound || post.status == .methodNotAllowed)
    }
  }
}
