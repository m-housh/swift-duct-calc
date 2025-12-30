import Dependencies
import DependenciesMacros
import Logging
import ManualDCore

extension DependencyValues {
  public var apiController: ApiController {
    get { self[ApiController.self] }
    set { self[ApiController.self] = newValue }
  }
}

@DependencyClient
public struct ApiController: Sendable {
  public var json: @Sendable (Request) async throws -> (any Encodable)?
}

extension ApiController {
  public struct Request: Sendable {
    public let route: SiteRoute.Api
    public let logger: Logger

    public init(route: SiteRoute.Api, logger: Logger) {
      self.route = route
      self.logger = logger
    }
  }
}

extension ApiController: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    json: { request in
      try await request.route.respond(logger: request.logger)
    }
  )
}
