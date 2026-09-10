import AuthClient
import Dependencies
import Elementary
import FittingClient
import ManualDCore
import Vapor
import VaporElementary
import ViewController

extension ViewController {
  func respond(route: SiteRoute.View, request: Vapor.Request) async throws
    -> any AsyncResponseEncodable
  {
    var route = route
    if case .fittingReference(var query) = route, query.q != nil {
      // HTML GET forms encode spaces as '+'. Decode with Vapor's form-query decoder
      // before rendering; URLRouting's query parser preserves a literal '+'.
      query.q = try request.query.get(String.self, at: "q")
      route = .fittingReference(query)
    }
    if case .fittingReference(let query) = route, query.download == "1" {
      @Dependency(\.auth.currentUser) var currentUser
      guard (try? currentUser()) != nil else { throw Abort(.unauthorized) }
      @Dependency(\.fittingClient) var fittingClient
      var exportQuery = query
      if !["json", "csv", "path"].contains(exportQuery.data ?? "") { exportQuery.data = "json" }
      let page = try FittingReferencePage(
        catalog: fittingClient.reference(), query: exportQuery, isLoggedIn: true)
      guard page.selected != nil else { throw Abort(.notFound) }
      return Response(
        status: .ok,
        headers: [
          "Content-Type": page.format == "csv"
            ? "text/csv; charset=utf-8" : "application/json; charset=utf-8",
          "Content-Disposition": "attachment; filename=\"\(page.filename)\"",
          "Cache-Control": "private, no-store", "Vary": "Cookie, HX-Request",
        ], body: .init(string: page.exportText))
    }
    if case .fittingReference = route, request.isHtmxRequest {
      // This page owns its stylesheet and scripts. Login's HTMX
      // continuation must load the full document rather than replace only the body.
      return Response(
        status: .ok,
        headers: [
          "HX-Redirect": request.url.string,
          "Cache-Control": "private, no-store",
          "Vary": "Cookie, HX-Request",
        ])
    }
    let content = try await view(
      .init(
        route: route,
        isHtmxRequest: request.isHtmxRequest,
        logger: request.logger
      )
    )
    @Dependency(\.auth.isAdministrator) var isAdministrator
    let html = withAdminVisibility(content, isAdministrator: await isAdministrator())
    if case .fittingReference = route {
      return AnyHTMLResponse(
        additionalHeaders: [
          "Cache-Control": "private, no-store", "Vary": "Cookie, HX-Request",
        ], value: html)
    }
    return AnyHTMLResponse(value: html)
  }
}

private func withAdminVisibility<Content: HTML & Sendable>(
  _ content: Content, isAdministrator: Bool
) -> AnySendableHTML {
  content.environment(AdminViewValue.$isAdministrator, isAdministrator)
}

// Re-adapted from `HTMLResponse` in the VaporElementary package to work with any html types
// returned from the view controller.
struct AnyHTMLResponse: AsyncResponseEncodable {

  public var chunkSize: Int
  public var headers: HTTPHeaders = ["Content-Type": "text/html; charset=utf-8"]
  var value: _SendableAnyHTMLBox

  init(chunkSize: Int = 1024, additionalHeaders: HTTPHeaders = [:], value: AnySendableHTML) {
    self.chunkSize = chunkSize
    if additionalHeaders.contains(name: .contentType) {
      self.headers = additionalHeaders
    } else {
      headers.add(contentsOf: additionalHeaders)
    }
    self.value = .init(value)
  }

  func encodeResponse(for request: Request) async throws -> Response {
    Response(
      status: .ok,
      headers: headers,
      // Managed streams finish with .error when rendering or a disconnected client throws.
      body: .init(managedAsyncStream: { [value, chunkSize] writer in
        guard let html = value.tryTake() else {
          assertionFailure("Non-sendable HTML value consumed more than once")
          request.logger.error("Non-sendable HTML value consumed more than once")
          throw Abort(.internalServerError)
        }
        try await writer.writeHTML(html, chunkSize: chunkSize)
      })
    )
  }
}
