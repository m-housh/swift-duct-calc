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
    func requireRoom(_ id: Room.ID) async throws {
      guard try await database.rooms.get(id)?.projectID == projectID else {
        throw Abort(.notFound)
      }
    }
    switch detail {
    case .equipment(.submit(let form)):
      try requireProject(form.projectID)
    case .equipment(.update(let id, _)):
      try await requireProject(database.equipment.get(id)?.projectID)
    case .rooms(.delete(let id)), .rooms(.update(let id, _)):
      try await requireRoom(id)
    case .rooms(.submit(let form)):
      if let id = form.delegatedTo { try await requireRoom(id) }
    case .rooms(.updateSensibleHeatRatio(let form)):
      try requireProject(form.projectID)
    case .componentLoss(.submit(let form)):
      try requireProject(form.projectID)
    case .frictionRate(.applyFilter(let selection)):
      if let id = selection.replacing {
        try await requireProject(database.componentLosses.get(id)?.projectID)
      }
    case .componentLoss(.delete(let id)), .componentLoss(.update(let id, _)):
      try await requireProject(database.componentLosses.get(id)?.projectID)
    case .ductSizing(.trunk(let route)):
      switch route {
      case .reorder(_, let ids):
        for id in ids {
          try await requireProject(database.trunkSizes.get(id)?.projectID)
        }
      case .delete(let id):
        try await requireProject(database.trunkSizes.get(id)?.projectID)
      case .update(let id, let form):
        try requireProject(form.projectID)
        try await requireProject(database.trunkSizes.get(id)?.projectID)
      case .submit(let form):
        try requireProject(form.projectID)
      }
    case .ductSizing(.roomRectangularForm(let id, _)),
      .ductSizing(.deleteRectangularSize(let id, _)):
      try await requireRoom(id)
    case .ductSizing(.rectangularSizes(let form)):
      for item in form.rooms { try await requireRoom(item.roomID) }
    case .ductSizing(.clearRectangularSizes(let rooms)):
      for item in rooms { try await requireRoom(item.roomID) }
    case .equivalentLength(.delete(let id)), .equivalentLength(.duplicate(let id)):
      // Stale paths keep the "no longer available" message the path pages show.
      guard try await database.equivalentLengths.get(id)?.projectID == projectID else {
        throw NotFoundError()
      }
    default: break
    }
    return try await next.respond(to: request)
  }
}
