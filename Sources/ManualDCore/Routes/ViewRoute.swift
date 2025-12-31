import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute {
  /// Represents view routes.
  ///
  /// The routes return html.
  public enum View: Equatable, Sendable {
    case project(ProjectRoute)
    case room(RoomRoute)

    public static let router = OneOf {
      Route(.case(Self.project)) {
        SiteRoute.View.ProjectRoute.router
      }
      Route(.case(Self.room)) {
        SiteRoute.View.RoomRoute.router
      }
    }
  }
}

extension SiteRoute.View {
  public enum ProjectRoute: Equatable, Sendable {
    case create(Project.Create)
    case form
    case index

    static let rootPath = "projects"

    public static let router = OneOf {
      Route(.case(Self.create)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("name", .string)
            Field("streetAddress", .string)
            Field("city", .string)
            Field("state", .string)
            Field("zipCode", .string)
          }
          .map(.memberwise(Project.Create.init))
        }
      }
      Route(.case(Self.form)) {
        Path {
          rootPath
          "create"
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

extension SiteRoute.View {
  public enum RoomRoute: Equatable, Sendable {
    case form
    case index

    static let rootPath = "rooms"

    public static let router = OneOf {
      Route(.case(Self.form)) {
        Path {
          rootPath
          "create"
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
