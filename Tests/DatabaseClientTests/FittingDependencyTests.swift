import Dependencies
import FittingClient
import Testing
import Vapor

@testable import App

struct FittingDependencyTests {
  @Test func catalogLoadFailurePreventsApplicationConfiguration() async throws {
    let app = try await Application.make(.testing)
    await #expect(throws: LoadError.unavailable) {
      try await configure(
        app, in: .init(),
        makeFittingClient: { throw LoadError.unavailable })
    }
    try await app.asyncShutdown()
  }

  @Test func middlewareInjectsThePreparedClientAcrossRequests() async throws {
    let app = try await Application.make(.testing)
    var fittingClient = FittingClient()
    fittingClient.groups = { _ in
      [
        .init(
          id: .supplyBoots, title: "Prepared catalog", representativeFittingID: nil,
          availableFittingCount: 0)
      ]
    }
    let middleware = DependenciesMiddleware(
      database: .testValue, environment: .init(), fittingClient: fittingClient)
    do {
      for _ in 0..<2 {
        let response = try await middleware.respond(
          to: Request(application: app, on: app.eventLoopGroup.next()),
          chainingTo: FittingResponder())
        #expect(response.status == .ok)
      }
      try await app.asyncShutdown()
    } catch {
      try await app.asyncShutdown()
      throw error
    }
  }

  private struct FittingResponder: AsyncResponder {
    func respond(to request: Request) async throws -> Response {
      @Dependency(\.fittingClient) var fittingClient
      let groups = try await fittingClient.groups(.supply)
      #expect(groups.map(\.title) == ["Prepared catalog"])
      return Response(status: .ok)
    }
  }

  private enum LoadError: Error {
    case unavailable
  }
}
