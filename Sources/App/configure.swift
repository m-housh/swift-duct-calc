import DatabaseClient
import Dependencies
import Elementary
import Fluent
import FluentSQLiteDriver
import ManualDCore
import NIOSSL
import ProjectClient
import Vapor
import VaporElementary
@preconcurrency import VaporRouting
import ViewController

// configures your application
public func configure(
  _ app: Application,
  makeDatabaseClient: @escaping (any Database) -> DatabaseClient = { .live(database: $0) }
) async throws {
  // Setup the database client.
  let databaseClient = try await setupDatabase(on: app, factory: makeDatabaseClient)
  // Add the global middlewares.
  addMiddleware(to: app, database: databaseClient)
  #if DEBUG
    // Live reload of the application for development when launched with the `./swift-dev` command
    // app.lifecycle.use(BrowserSyncHandler())
  #endif
  // Add our route handlers.
  addRoutes(to: app)
  if app.environment != .testing {
    try await app.autoMigrate()
  }
  // Add our custom cli-commands to the application.
  addCommands(to: app)
}

private func addMiddleware(to app: Application, database databaseClient: DatabaseClient) {
  // cors middleware should come before default error middleware using `at: .beginning`
  let corsConfiguration = CORSMiddleware.Configuration(
    allowedOrigin: .all,
    allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
    allowedHeaders: [
      .accept, .authorization, .contentType, .origin,
      .xRequestedWith, .userAgent, .accessControlAllowOrigin,
    ]
  )
  let cors = CORSMiddleware(configuration: corsConfiguration)
  app.middleware.use(cors, at: .beginning)

  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
  app.middleware.use(app.sessions.middleware)
  app.middleware.use(DependenciesMiddleware(database: databaseClient))
}

private func setupDatabase(
  on app: Application,
  factory makeDatabaseClient: @escaping (any Database) -> DatabaseClient
) async throws -> DatabaseClient {
  switch app.environment {
  case .production, .development:
    let dbFileName = Environment.get("SQLITE_FILENAME") ?? "db.sqlite"
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(dbFileName)), as: .sqlite)
  default:
    app.databases.use(DatabaseConfigurationFactory.sqlite(.memory), as: .sqlite)
  }

  let databaseClient = makeDatabaseClient(app.db)

  if app.environment != .testing {
    try await app.migrations.add(databaseClient.migrations.run())
  }

  return databaseClient
}

private func addRoutes(to app: Application) {
  // Redirect the index path to project route.
  app.get { req in
    req.redirect(to: SiteRoute.View.router.path(for: .project(.index)))
  }

  app.mount(
    SiteRoute.router,
    middleware: {
      if app.environment == .testing {
        return nil
      } else {
        return $0.middleware()
      }
    },
    use: siteHandler
  )
}

private func addCommands(to app: Application) {
  // #if DEBUG
  //   app.asyncCommands.use(SeedCommand(), as: "seed")
  // #endif
  // app.asyncCommands.use(GenerateAdminUserCommand(), as: "generate-admin")
}

extension SiteRoute {

  fileprivate func middleware() -> [any Middleware]? {
    switch self {
    case .api:
      return nil
    case .health:
      return nil
    case .view(let route):
      return route.middleware
    }
  }
}

extension DuctSizes: Content {}

@Sendable
private func siteHandler(
  request: Request,
  route: SiteRoute
) async throws -> any AsyncResponseEncodable {
  @Dependency(\.apiController) var apiController
  @Dependency(\.viewController) var viewController
  @Dependency(\.projectClient) var projectClient

  switch route {
  case .api(let route):
    return try await apiController.respond(route, request: request)
  case .health:
    return HTTPStatus.ok
  // Generating a pdf return's a `Response` instead of `HTML` like other views, so we
  // need to handle it seperately.
  case .view(.project(.detail(let projectID, .pdf))):
    return try await projectClient.generatePdf(projectID)
  case .view(let route):
    return try await viewController.respond(route: route, request: request)
  }
}
