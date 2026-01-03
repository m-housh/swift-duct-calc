import DatabaseClient
import Dependencies
import Logging
import ManualDCore

extension SiteRoute.Api {
  func respond(logger: Logger) async throws -> (any Encodable)? {
    switch self {
    case .project(let route):
      return try await route.respond(logger: logger)
    case .room(let route):
      return try await route.respond(logger: logger)
    case .equipment(let route):
      return try await route.respond(logger: logger)
    case .componentLoss(let route):
      return try await route.respond(logger: logger)
    }
  }
}

extension SiteRoute.Api.ProjectRoute {

  func respond(logger: Logger) async throws -> (any Encodable)? {
    @Dependency(\.database) var database

    switch self {
    case .create(let request):
      // return try await database.projects.create(request)
      // FIX:
      fatalError()
    case .delete(let id):
      try await database.projects.delete(id)
      return nil
    case .get(let id):
      guard let project = try await database.projects.get(id) else {
        logger.error("Project not found for id: \(id)")
        throw ApiError("Project not found.")
      }
      return project
    case .index:
      // FIX: Fix to return projects.
      return [Project]()
    }
  }
}

extension SiteRoute.Api.RoomRoute {

  func respond(logger: Logger) async throws -> (any Encodable)? {
    @Dependency(\.database) var database

    switch self {
    case .create(let request):
      return try await database.rooms.create(request)
    case .delete(let id):
      try await database.rooms.delete(id)
      return nil
    case .get(let id):
      guard let room = try await database.rooms.get(id) else {
        logger.error("Room not found for id: \(id)")
        throw ApiError("Room not found.")
      }
      return room
    }
  }
}

extension SiteRoute.Api.EquipmentRoute {

  func respond(logger: Logger) async throws -> (any Encodable)? {
    @Dependency(\.database) var database

    switch self {
    case .create(let request):
      return try await database.equipment.create(request)
    case .delete(let id):
      try await database.equipment.delete(id)
      return nil
    case .fetch(let projectID):
      return try await database.equipment.fetch(projectID)
    case .get(let id):
      guard let room = try await database.equipment.get(id) else {
        logger.error("Equipment not found for id: \(id)")
        throw ApiError("Equipment not found.")
      }
      return room
    }
  }
}

extension SiteRoute.Api.ComponentLossRoute {

  func respond(logger: Logger) async throws -> (any Encodable)? {
    @Dependency(\.database) var database

    switch self {
    case .create(let request):
      return try await database.componentLoss.create(request)
    case .delete(let id):
      try await database.componentLoss.delete(id)
      return nil
    case .fetch(let projectID):
      return try await database.componentLoss.fetch(projectID)
    case .get(let id):
      guard let room = try await database.componentLoss.get(id) else {
        logger.error("Component loss not found for id: \(id)")
        throw ApiError("Component loss not found.")
      }
      return room
    }
  }
}

public struct ApiError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}
