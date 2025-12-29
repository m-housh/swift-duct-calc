import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute {
  /// Represents api routes.
  ///
  /// The routes return json as opposed to view routes that return html.
  public enum Api: Sendable, Equatable {

    case project(Self.ProjectRoute)
    case room(Self.RoomRoute)
    case equipment(Self.EquipmentRoute)
    case componentLoss(Self.ComponentLossRoute)

    public static let rootPath = Path {
      "api"
      "v1"
    }

    public static let router = OneOf {
      Route(.case(Self.project)) {
        rootPath
        ProjectRoute.router
      }
      Route(.case(Self.room)) {
        rootPath
        RoomRoute.router
      }
      Route(.case(Self.equipment)) {
        rootPath
        EquipmentRoute.router
      }
      Route(.case(Self.componentLoss)) {
        rootPath
        ComponentLossRoute.router
      }
    }

  }

}

extension SiteRoute.Api {
  public enum ProjectRoute: Sendable, Equatable {
    case create(Project.Create)
    case delete(id: Project.ID)
    case get(id: Project.ID)
    case index

    static let rootPath = "projects"

    public static let router = OneOf {
      Route(.case(Self.create)) {
        Path { rootPath }
        Method.post
        Body(.json(Project.Create.self))
      }
      Route(.case(Self.delete(id:))) {
        Path {
          rootPath
          Project.ID.parser()
        }
        Method.delete
      }
      Route(.case(Self.get(id:))) {
        Path {
          rootPath
          Project.ID.parser()
        }
        Method.get
      }
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
    }
  }
}

extension SiteRoute.Api {

  public enum RoomRoute: Sendable, Equatable {
    case create(Room.Create)
    case delete(id: Room.ID)
    case get(id: Room.ID)

    static let rootPath = "rooms"

    public static let router = OneOf {
      Route(.case(Self.create)) {
        Path { rootPath }
        Method.post
        Body(.json(Room.Create.self))
      }
      Route(.case(Self.delete(id:))) {
        Path {
          rootPath
          Room.ID.parser()
        }
        Method.delete
      }
      Route(.case(Self.get(id:))) {
        Path {
          rootPath
          Room.ID.parser()
        }
        Method.get
      }
    }
  }
}

extension SiteRoute.Api {

  public enum EquipmentRoute: Sendable, Equatable {
    case create(EquipmentInfo.Create)
    case delete(id: EquipmentInfo.ID)
    case fetch(projectID: Project.ID)
    case get(id: EquipmentInfo.ID)

    static let rootPath = "equipment"

    public static let router = OneOf {
      Route(.case(Self.create)) {
        Path { rootPath }
        Method.post
        Body(.json(EquipmentInfo.Create.self))
      }
      Route(.case(Self.delete(id:))) {
        Path {
          rootPath
          EquipmentInfo.ID.parser()
        }
        Method.delete
      }
      Route(.case(Self.fetch(projectID:))) {
        Path { rootPath }
        Method.get
        Query {
          Field("projectID") { Project.ID.parser() }
        }
      }
      Route(.case(Self.get(id:))) {
        Path {
          rootPath
          EquipmentInfo.ID.parser()
        }
        Method.get
      }
    }
  }
}

extension SiteRoute.Api {

  public enum ComponentLossRoute: Sendable, Equatable {
    case create(ComponentPressureLoss.Create)
    case delete(id: ComponentPressureLoss.ID)
    case fetch(projectID: Project.ID)
    case get(id: ComponentPressureLoss.ID)

    static let rootPath = "componentLoss"

    public static let router = OneOf {
      Route(.case(Self.create)) {
        Path { rootPath }
        Method.post
        Body(.json(ComponentPressureLoss.Create.self))
      }
      Route(.case(Self.delete(id:))) {
        Path {
          rootPath
          ComponentPressureLoss.ID.parser()
        }
        Method.delete
      }
      Route(.case(Self.fetch(projectID:))) {
        Path { rootPath }
        Method.get
        Query {
          Field("projectID") { Project.ID.parser() }
        }
      }
      Route(.case(Self.get(id:))) {
        Path {
          rootPath
          ComponentPressureLoss.ID.parser()
        }
        Method.get
      }
    }
  }
}
