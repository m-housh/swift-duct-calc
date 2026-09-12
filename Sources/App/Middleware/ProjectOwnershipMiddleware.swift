import DatabaseClient
import ManualDCore
import Vapor

/// Protects every project entry point, including PDF generation and project deletion.
struct ProjectOwnershipMiddleware: AsyncMiddleware {
  let projectID: Project.ID
  var detail: SiteRoute.View.ProjectRoute.DetailRoute? = nil

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let user = try request.auth.require(User.self)
    let database = DatabaseClient.live(database: request.db)
    guard try await database.projects.getForUser(projectID, user.id) != nil else {
      throw Abort(.notFound)
    }
    func requireProject(_ id: Project.ID?) throws {
      guard id == projectID else { throw Abort(.notFound) }
    }
    func requireRoom(_ id: Room.ID) async throws -> Room {
      guard let room = try await database.rooms.get(id), room.projectID == projectID else {
        throw Abort(.notFound)
      }
      return room
    }
    switch detail {
    case .equipment(.submit(let form)):
      try requireProject(form.projectID)
    case .equipment(.update(let id, _)):
      try await requireProject(database.equipment.get(id)?.projectID)
    case .rooms(.delete(let id)), .rooms(.update(let id, _)):
      _ = try await requireRoom(id)
    case .rooms(.submit(let form)):
      if let id = form.delegatedTo { _ = try await requireRoom(id) }
    case .rooms(.updateSensibleHeatRatio(let form)):
      try requireProject(form.projectID)
    case .componentLoss(.submit(let form)):
      try requireProject(form.projectID)
    case .componentLoss(.delete(let id)), .componentLoss(.update(let id, _)):
      try await requireProject(database.componentLosses.get(id)?.projectID)
    case .ductSizing(.trunk(let route)):
      switch route {
      case .delete(let id):
        try await requireProject(database.trunkSizes.get(id)?.projectID)
      case .update(let id, let form):
        try requireProject(form.projectID)
        try await requireProject(database.trunkSizes.get(id)?.projectID)
      case .submit(let form):
        try requireProject(form.projectID)
      }
    case .ductSizing(.roomRectangularForm(let id, let form)):
      let room = try await requireRoom(id)
      guard room.delegatedTo == nil, form.register > 0, form.register <= room.registerCount,
        form.height > 0
      else { throw Abort(.badRequest, reason: "Choose a valid register and a positive height.") }
      if let sizeID = form.id {
        guard
          room.rectangularSizes?.contains(where: {
            $0.id == sizeID && ($0.register == nil || $0.register == form.register)
          }) == true
        else { throw Abort(.notFound) }
      }
    case .ductSizing(.deleteRectangularSize(let id, let form)):
      let room = try await requireRoom(id)
      guard form.register > 0, form.register <= room.registerCount,
        room.rectangularSizes?.contains(where: {
          $0.id == form.rectangularSizeID && ($0.register == nil || $0.register == form.register)
        }) == true
      else { throw Abort(.notFound) }
    default: break
    }
    return try await next.respond(to: request)
  }
}
