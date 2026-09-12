import DatabaseClient
import Elementary
import Foundation
import ManualDCore
import Testing
import URLRouting

@testable import ViewController

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite
struct EquivalentLengthFormTests {
  typealias Route = SiteRoute.View.ProjectRoute.EquivalentLengthRoute

  @Test(arguments: [EquivalentLength.EffectiveLengthType.supply, .return])
  func pathEditorTypeRoundTrips(type: EquivalentLength.EffectiveLengthType) throws {
    for id: UUID? in [nil, UUID(1)] {
      let route = Route.editor(id, type: type)
      let request = URLRequest(
        url: URL(string: "http://localhost" + Route.router.path(for: route))!)
      #expect(try Route.router.match(request: request) == route)
    }
    #expect(try Route.router.match(path: "/effective-lengths/editor") == .editor(nil))
  }

  @Test(arguments: ["supply", "return"])
  func templateDraftSurvivesChooserAndStartRoutes(type: String) throws {
    let draft = #"{"name":"Supply + \"East\" & <West>","straightLengths":[10,25,15]}"#
    let typedDraft = draft.dropLast() + #","type":""# + type + #""}"#
    let values = try GuidedPath.InitialValues(draft: typedDraft)
    #expect(values.name == "Supply + \"East\" & <West>")
    #expect(values.straightLengths == [10, 25, 15])
    #expect(values.type?.rawValue == type)
    let routes: [Route.GuidedRoute] = [
      .index(draft: typedDraft), .start(UUID(), draft: typedDraft),
      .index(), .start(UUID()),
    ]
    for route in routes {
      let request = URLRequest(
        url: URL(string: "http://localhost" + Route.GuidedRoute.router.path(for: route))!)
      #expect(try Route.GuidedRoute.router.match(request: request) == route)
    }
  }

  @Test(arguments: [EquivalentLength.EffectiveLengthType.supply, .return], [false, true])
  func chooserPrioritizesDraftTypeWithoutHidingOtherTemplates(
    type: EquivalentLength.EffectiveLengthType, hasMatching: Bool
  ) throws {
    let other: EquivalentLength.EffectiveLengthType = type == .supply ? .return : .supply
    func template(_ type: EquivalentLength.EffectiveLengthType) -> PathTemplate {
      .init(
        id: UUID(), userID: UUID(), revision: UUID(),
        configuration: .init(name: "Saved \(type.rawValue)", type: type, steps: []),
        createdAt: .now, updatedAt: .now)
    }
    let projectID = UUID()
    let templates = [template(other)] + (hasMatching ? [template(type)] : [])
    let draft =
      "{\"name\":\"East + West\",\"type\":\"\(type.rawValue)\",\"straightLengths\":[10,25,15]}"
    let html = PathTemplatesView(
      templates: templates, projectID: projectID, choosing: true, draft: draft,
      preferredType: try GuidedPath.InitialValues(draft: draft).type
    ).render()
    let preferred = try #require(html.range(of: "data-template-type=\"\(type.rawValue)\""))
    let remaining = try #require(html.range(of: "data-template-type=\"\(other.rawValue)\""))
    #expect(preferred.lowerBound < remaining.lowerBound)
    #expect(html.contains("Saved \(other.rawValue)"))
    #expect(html.contains("No \(type.rawValue) templates.") == !hasMatching)
    #expect(!html.contains("Use starter"))
    let links = try NSRegularExpression(
      pattern: #"(?:href|action)="([^"]*/start/[^"]+)""#
    )
    .matches(in: html, range: NSRange(html.startIndex..., in: html))
    #expect(links.count == templates.count)
    for link in links {
      let range = try #require(Range(link.range(at: 1), in: html))
      let url = try #require(URLComponents(string: String(html[range])))
      #expect(url.queryItems?.first { $0.name == "draft" }?.value == draft)
    }

  }

  @Test
  func invalidTemplateDraftsAreRejected() throws {
    for draft in [
      #"{"name":"Test","straightLengths":[-1]}"#,
      #"{"name":"Test","straightLengths":[0]}"#,
      #"{"name":"Test","straightLengths":[10.5]}"#,
      #"{"name":"Test","straightLengths":"10,25"}"#,
      #"{"name":"Test","type":"invalid","straightLengths":[]}"#,
      String(repeating: "x", count: 4097),
    ] {
      #expect(throws: (any Error).self) { try GuidedPath.InitialValues(draft: draft) }
    }
    let empty = try GuidedPath.InitialValues(draft: #"{"name":"","straightLengths":[]}"#)
    #expect(empty.name.isEmpty && empty.straightLengths.isEmpty && empty.type == nil)
  }

  @Test func legacyEditorRoutesAreRemoved() {
    for suffix in ["stepOne", "stepTwo", "stepThree", "field?type=group"] {
      var request = URLRequest(url: URL(string: "http://localhost/effective-lengths/" + suffix)!)
      request.httpMethod = suffix.hasPrefix("field") ? "GET" : "POST"
      #expect(throws: (any Error).self) { try Route.router.match(request: request) }
    }
  }
}
