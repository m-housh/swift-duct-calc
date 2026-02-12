import DatabaseClient
import Dependencies
import Elementary
import EnvVars
import Fluent
import FluentPostgresDriver
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
  in environment: EnvVars,
  makeDatabaseClient: @escaping (any Database) -> DatabaseClient = { .live(database: $0) }
) async throws {
  // Setup the database client.
  let databaseClient = try await setupDatabase(
    on: app, environment: environment, factory: makeDatabaseClient
  )
  // Add the global middlewares.
  addMiddleware(to: app, database: databaseClient, environment: environment)
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

private func addMiddleware(
  to app: Application,
  database databaseClient: DatabaseClient,
  environment: EnvVars
) {
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

  // Sessions.
  app.sessions.use(.fluent)
  app.migrations.add(SessionRecord.migration)
  app.middleware.use(app.sessions.middleware)

  app.middleware.use(DependenciesMiddleware(database: databaseClient, environment: environment))
}

private func setupDatabase(
  on app: Application,
  environment: EnvVars,
  factory makeDatabaseClient: @escaping (any Database) -> DatabaseClient
) async throws -> DatabaseClient {
  switch app.environment {
  case .production:
    let configuration = try environment.postgresConfiguration()
    app.databases.use(.postgres(configuration: configuration), as: .psql)
  case .development:
    let dbFileName = environment.sqlitePath ?? "db.sqlite"
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(dbFileName)), as: .sqlite)
  default:
    app.databases.use(DatabaseConfigurationFactory.sqlite(.memory), as: .sqlite)
  }

  let databaseClient = makeDatabaseClient(app.db)

  try await app.migrations.add(databaseClient.migrations())

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
  @Dependency(\.viewController) var viewController
  @Dependency(\.projectClient) var projectClient

  switch route {
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

extension EnvVars {
  func postgresConfiguration() throws -> SQLPostgresConfiguration {
    guard let hostname = postgresHostname,
      let username = postgresUsername,
      let password = postgresPassword,
      let database = postgresDatabase
    else {
      throw EnvError("Missing environment variables for postgres connection.")
    }
    return .init(
      hostname: hostname,
      username: username,
      password: password,
      database: database,
      tls: .disable
    )
  }
}

struct EnvError: Error {
  let reason: String

  init(_ reason: String) {
    self.reason = reason
  }
}
