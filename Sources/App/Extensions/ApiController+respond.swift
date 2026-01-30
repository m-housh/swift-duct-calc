// import ApiController
// import ManualDCore
// import Vapor
//
// extension ApiController {
//
//   func respond(_ route: SiteRoute.Api, request: Vapor.Request) async throws
//     -> any AsyncResponseEncodable
//   {
//     guard let encodable = try await json(.init(route: route, logger: request.logger)) else {
//       return HTTPStatus.ok
//     }
//     return AnyJSONResponse(value: encodable)
//   }
// }
//
// struct AnyJSONResponse: AsyncResponseEncodable {
//   public var headers: HTTPHeaders = ["Content-Type": "application/json"]
//   let value: any Encodable
//
//   init(additionalHeaders: HTTPHeaders = [:], value: any Encodable) {
//     if additionalHeaders.contains(name: .contentType) {
//       self.headers = additionalHeaders
//     } else {
//       headers.add(contentsOf: additionalHeaders)
//     }
//     self.value = value
//   }
//
//   func encodeResponse(for request: Request) async throws -> Response {
//     try Response(
//       status: .ok,
//       headers: headers,
//       body: .init(data: JSONEncoder().encode(value))
//     )
//   }
// }
