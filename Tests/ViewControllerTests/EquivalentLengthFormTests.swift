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

  @Test
  func templateDraftSurvivesChooserAndStartRoutes() throws {
    let draft = #"{"name":"Supply + \"East\" & <West>","straightLengths":[10,25,15]}"#
    let values = try GuidedPath.InitialValues(draft: draft)
    #expect(values.name == "Supply + \"East\" & <West>")
    #expect(values.straightLengths == [10, 25, 15])
    let routes: [Route.GuidedRoute] = [
      .index(draft: draft), .start(UUID(), draft: draft), .starter(.return, draft: draft),
      .index(), .start(UUID()), .starter(.supply),
    ]
    for route in routes {
      var request = URLRequest(
        url: URL(string: "http://localhost" + Route.GuidedRoute.router.path(for: route))!)
      if case .starter = route { request.httpMethod = "POST" }
      #expect(try Route.GuidedRoute.router.match(request: request) == route)
    }
  }

  @Test
  func invalidTemplateDraftsAreRejected() throws {
    for draft in [
      #"{"name":"Test","straightLengths":[-1]}"#,
      #"{"name":"Test","straightLengths":[0]}"#,
      #"{"name":"Test","straightLengths":[10.5]}"#,
      #"{"name":"Test","straightLengths":"10,25"}"#,
      String(repeating: "x", count: 4097),
    ] {
      #expect(throws: (any Error).self) { try GuidedPath.InitialValues(draft: draft) }
    }
    let empty = try GuidedPath.InitialValues(draft: #"{"name":"","straightLengths":[]}"#)
    #expect(empty.name.isEmpty && empty.straightLengths.isEmpty)
  }

  @Test(arguments: ["POST", "PATCH"])
  func fractionalLengthsSurviveFormSubmission(method: String) throws {
    let form = try parseForm(method: method, lengths: ["10.25", "7.5"])
    try form.validate()

    let expected = [
      EquivalentLength.FittingGroup(group: 8, letter: "A", value: 10.25, quantity: 2),
      EquivalentLength.FittingGroup(group: 12, letter: "J", value: 7.5),
    ]
    let projectID = UUID()
    let create = try EquivalentLength.Create(form: form, projectID: projectID)
    let update = try EquivalentLength.Update(form: form, projectID: projectID)

    #expect(create.groups == expected)
    #expect(update.groups == expected)
    #expect(create.groups.totalEquivalentLength == 28)
    #expect(create.straightLengths == [10])
  }

  @Test(arguments: ["POST", "PATCH"])
  func wholeLengthsRemainAccepted(method: String) throws {
    let form = try parseForm(method: method, lengths: ["10", "7"])
    try form.validate()
    #expect(form.groupLengths == [10, 7])
  }

  @Test(arguments: ["0", "-0.25", "nan", "inf", "1e999", "abc"])
  func invalidLengthsCannotBeSubmitted(length: String) {
    for method in ["POST", "PATCH"] {
      #expect(throws: (any Error).self) {
        let form = try parseForm(method: method, lengths: [length, "7.5"])
        if method == "POST" {
          _ = try EquivalentLength.Create(form: form, projectID: UUID())
        } else {
          _ = try EquivalentLength.Update(form: form, projectID: UUID())
        }
      }
    }
  }

  @Test
  func mismatchedRowsAreRejectedBeforeConversion() throws {
    let form = try parseForm(method: "POST", lengths: ["10.25"])
    #expect(throws: ValidationError.self) {
      try EquivalentLength.Create(form: form, projectID: UUID())
    }
    #expect(throws: ValidationError.self) {
      try EquivalentLength.Update(form: form, projectID: UUID())
    }
  }

  @Test
  func editFieldAllowsAndRetainsFractionalLength() {
    let html = GroupField(
      style: .supply,
      group: .init(group: 8, letter: "A", value: 10.25, quantity: 2)
    ).render()
    #expect(html.contains("step=\"any\""))
    #expect(html.contains("value=\"10.25\""))
  }

  private func parseForm(method: String, lengths: [String]) throws -> Route.StepThree {
    let path = method == "POST" ? "stepThree" : "00000000-0000-0000-0000-000000000001"
    var request = URLRequest(url: URL(string: "http://localhost/effective-lengths/\(path)")!)
    request.httpMethod = method
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(
      ("name=Test&type=supply&straightLengths=10"
        + "&group%5Bgroup%5D=8&group%5Bgroup%5D=12"
        + "&group%5Bletter%5D=A&group%5Bletter%5D=J"
        + lengths.map { "&group%5Blength%5D=\($0)" }.joined()
        + "&group%5Bquantity%5D=2&group%5Bquantity%5D=1").utf8
    )

    switch try Route.router.match(request: request) {
    case .submit(.three(let form)), .update(_, let form):
      return form
    default:
      throw UnexpectedRoute()
    }
  }

  private struct UnexpectedRoute: Error {}
}
