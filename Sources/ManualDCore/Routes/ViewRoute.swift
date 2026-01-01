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
    case frictionRate(FrictionRateRoute)

    public static let router = OneOf {
      Route(.case(Self.project)) {
        SiteRoute.View.ProjectRoute.router
      }
      Route(.case(Self.room)) {
        SiteRoute.View.RoomRoute.router
      }
      Route(.case(Self.frictionRate)) {
        SiteRoute.View.FrictionRateRoute.router
      }
    }
  }
}

extension SiteRoute.View {
  public enum ProjectRoute: Equatable, Sendable {
    case create(Project.Create)
    case form(dismiss: Bool = false)
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
        Query {
          Field("dismiss", default: false) { Bool.parser() }
        }
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
    case form(dismiss: Bool = false)
    case index

    static let rootPath = "rooms"

    public static let router = OneOf {
      Route(.case(Self.form)) {
        Path {
          rootPath
          "create"
        }
        Method.get
        Query {
          Field("dismiss", default: false) { Bool.parser() }
        }
      }
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
    }
  }
}

extension SiteRoute.View {
  public enum FrictionRateRoute: Equatable, Sendable {
    case index
    case form(FormType, dismiss: Bool = false)

    static let rootPath = "friction-rate"

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
      Route(.case(Self.form)) {
        Path {
          rootPath
          "create"
        }
        Method.get
        Query {
          Field("type") { FormType.parser() }
          Field("dismiss", default: false) { Bool.parser() }
        }
      }
    }
  }
}

extension SiteRoute.View.FrictionRateRoute {
  public enum FormType: String, CaseIterable, Codable, Equatable, Sendable {
    case equipmentInfo
    case componentPressureLoss
  }
}
