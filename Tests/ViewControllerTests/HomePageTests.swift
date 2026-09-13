import AuthClient
import Dependencies
import Elementary
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing
import URLRouting

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct HomePageTests {
  @Test func returningVisitor() {
    let page = HomePage(isLoggedIn: true)
    let html = page.render()
    #expect(html.contains("Open your projects"))
    #expect(html.contains("href=\"/projects\""))
    #expect(!html.contains("href=\"/signup\""))
    #expect(!html.contains("href=\"/login\""))
    assertSnapshot(of: page, as: .html)
  }

  @Test func publicHome() {
    let html = HomePage().render()
    #expect(html.contains("<title>DuctCalc · Residential duct design</title>"))
    #expect(html.contains("name=\"description\""))
    #expect(html.contains("href=\"/signup\""))
    #expect(html.contains("href=\"/login\""))
    #expect(html.contains("href=\"/ductulator\""))
    #expect(html.contains("Try the ductulator"))
    #expect(!html.contains("noindex"))
    #expect(!html.contains("prototype"))
    #expect(!html.contains("srcdoc="))
    #expect(html.utf8.count < 15_000)
  }

  @Test(arguments: HomePreviewStep.allCases)
  func preview(_ step: HomePreviewStep) async throws {
    try await withDependencies {
      $0.viewController = .liveValue
      $0.auth = .failing
    } operation: {
      @Dependency(\.viewController) var controller
      let page = try await controller.view(.test(.homePreview(step)))
      let html = page.render()
      #expect(html.contains("noindex, nofollow"))
      #expect(html.contains("<div inert=\"\""))
      #expect(html.contains("Maple Avenue"))
      #expect(!html.contains("<script"))
      assertSnapshot(of: page, as: .html, named: step.rawValue)
    }
  }

  @Test(arguments: HomePreviewStep.allCases)
  func previewRoute(_ step: HomePreviewStep) throws {
    let route = SiteRoute.View.homePreview(step)
    let path = SiteRoute.View.router.path(for: route)
    #expect(path == "/home-preview/\(step.rawValue)")
    #expect(try SiteRoute.View.router.parse(URLRequestData(string: path)!) == route)
    #expect(throws: (any Error).self) {
      try SiteRoute.View.router.parse(URLRequestData(method: "POST", path: path))
    }
  }
}
