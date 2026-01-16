import Elementary
import ManualDCore
import Vapor
import VaporElementary
import ViewController

extension ViewController {
  func respond(route: SiteRoute.View, request: Vapor.Request) async throws
    -> any AsyncResponseEncodable
  {
    let html = try await view(
      .init(
        route: route,
        isHtmxRequest: request.isHtmxRequest,
        logger: request.logger
      )
    )
    return AnyHTMLResponse(value: html)
  }
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
      body: .init(asyncStream: { [value, chunkSize] writer in
        guard let html = value.tryTake() else {
          assertionFailure("Non-sendable HTML value consumed more than once")
          request.logger.error("Non-sendable HTML value consumed more than once")
          throw Abort(.internalServerError)
        }
        try await writer.writeHTML(html, chunkSize: chunkSize)
        try await writer.write(.end)

      })
    )
  }
}
