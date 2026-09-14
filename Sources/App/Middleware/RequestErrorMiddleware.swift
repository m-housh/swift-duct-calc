import Foundation
import ManualDCore
import Vapor
import ViewController

struct ViewRouteKey: StorageKey { typealias Value = SiteRoute.View }

/// Failed actions keep their existing document. Direct navigation gets an HTML error page.
struct RequestErrorMiddleware: AsyncMiddleware {
  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    do {
      let response = try await next.respond(to: request)
      // The authentication middleware redirects guests. An expired session must not replace a draft.
      if isInteractive(request), response.status == .seeOther || response.status == .found,
        response.headers.first(name: .location)?.hasPrefix("/login") == true
      {
        throw Abort(.unauthorized)
      }
      return response
    } catch {
      let route = request.storage[ViewRouteKey.self]
      let title =
        route?.failureTitle
        ?? (request.method == .GET ? "Could not open page" : "Could not complete request")
      let reference = UUID().uuidString
      var failure = ViewController.present(error, title: title, reference: reference)
      if case .login(.submit) = route, failure.status == 401 || failure.status == 404 {
        failure = .init(
          title: "Could not sign in",
          message: "The email address or password is incorrect. Try again.", status: 401)
      }
      if failure.reference != nil {
        // Error descriptions can contain SQL bindings, credentials, or uploaded documents.
        let underlying =
          (error as? SavedChangeRefreshError)?.underlying
          ?? (error as? AccountCreatedError)?.underlying ?? error
        let nsError = underlying as NSError
        request.logger.error(
          "Request failed",
          metadata: [
            "error-reference": .string(reference),
            "error-type": .string(String(reflecting: type(of: underlying))),
            "error-domain": .string(nsError.domain), "error-code": .string("\(nsError.code)"),
            "operation": .string(title),
          ])
      }
      let status = HTTPResponseStatus(statusCode: failure.status)
      let headers: HTTPHeaders = [
        "Cache-Control": "no-store", "Vary": "Cookie, HX-Request, X-DuctCalc-Request",
      ]
      if isInteractive(request) {
        let response = Response(status: status, headers: headers)
        response.headers.contentType = .init(
          type: "application", subType: "vnd.ductcalc.error+json")
        response.body = .init(data: try JSONEncoder().encode(failure))
        return response
      }
      let html = await ViewController.Request(
        route: route ?? .home, isHtmxRequest: false, logger: request.logger
      ).errorPage(failure)
      let response = try await AnyHTMLResponse(additionalHeaders: headers, value: html)
        .encodeResponse(for: request)
      response.status = status
      return response
    }
  }

  private func isInteractive(_ request: Request) -> Bool {
    request.isHtmxRequest || request.headers.first(name: "X-DuctCalc-Request") == "true"
  }
}
