import ApiController
import DatabaseClient
import Dependencies
import Vapor
import ViewController

// Taken from discussions page on `swift-dependencies`.

// FIX: Use live view controller.
struct DependenciesMiddleware: AsyncMiddleware {

  private let values: DependencyValues.Continuation
  private let apiController: ApiController
  private let database: DatabaseClient
  private let viewController: ViewController

  init(
    database: DatabaseClient,
    apiController: ApiController = .liveValue,
    viewController: ViewController = .liveValue
  ) {
    self.values = withEscapedDependencies { $0 }
    self.apiController = apiController
    self.database = database
    self.viewController = viewController
  }

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    try await values.yield {
      try await withDependencies {
        $0.apiController = apiController
        $0.database = database
        // $0.dateFormatter = .liveValue
        $0.viewController = viewController
      } operation: {
        try await next.respond(to: request)
      }
    }
  }

}
