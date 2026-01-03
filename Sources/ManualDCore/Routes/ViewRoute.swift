import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute {
  /// Represents view routes.
  ///
  /// The routes return html.
  public enum View: Equatable, Sendable {
    case login(LoginRoute)
    case signup(SignupRoute)
    case project(ProjectRoute)
    case room(RoomRoute)
    case frictionRate(FrictionRateRoute)
    case effectiveLength(EffectiveLengthRoute)
    // case user(UserRoute)

    public static let router = OneOf {
      Route(.case(Self.login)) {
        SiteRoute.View.LoginRoute.router
      }
      Route(.case(Self.signup)) {
        SiteRoute.View.SignupRoute.router
      }
      Route(.case(Self.project)) {
        SiteRoute.View.ProjectRoute.router
      }
      Route(.case(Self.room)) {
        SiteRoute.View.RoomRoute.router
      }
      Route(.case(Self.frictionRate)) {
        SiteRoute.View.FrictionRateRoute.router
      }
      Route(.case(Self.effectiveLength)) {
        SiteRoute.View.EffectiveLengthRoute.router
      }
      // Route(.case(Self.user)) {
      //   SiteRoute.View.UserRoute.router
      // }
    }
  }
}

extension SiteRoute.View {
  public enum ProjectRoute: Equatable, Sendable {
    case create(Project.Create)
    case form(dismiss: Bool = false)
    case index
    case page(page: Int = 1, limit: Int = 25)

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
      Route(.case(Self.page(page:limit:))) {
        Path {
          rootPath
          "page"
        }
        Method.get
        Query {
          Field("page", default: 1) { Int.parser() }
          Field("limit", default: 25) { Int.parser() }
        }
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

extension SiteRoute.View {
  public enum EffectiveLengthRoute: Equatable, Sendable {
    case field(FieldType)
    case form(dismiss: Bool = false)
    case index

    static let rootPath = "effective-lengths"

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
      Route(.case(Self.form(dismiss:))) {
        Path {
          rootPath
          "create"
        }
        Method.get
        Query {
          Field("dismiss", default: false) { Bool.parser() }
        }
      }
      Route(.case(Self.field)) {
        Path {
          rootPath
          "field"
        }
        Method.get
        Query {
          Field("type") { FieldType.parser() }
        }
      }
    }
  }
}

extension SiteRoute.View.EffectiveLengthRoute {
  public enum FieldType: String, CaseIterable, Equatable, Sendable {
    case straightLength
    case group
  }
}

// extension SiteRoute.View {
//   public enum UserRoute: Equatable, Sendable {
//     case signup(Signup)
//
//     public static let router = OneOf {
//       Route(.case(Self.signup)) {
//         SiteRoute.View.UserRoute.Signup.router
//       }
//     }
//   }
// }

extension SiteRoute.View {

  public enum LoginRoute: Equatable, Sendable {
    case index
    case submit(User.Login)

    static let rootPath = "login"

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
      Route(.case(Self.submit)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("email", .string)
            Field("password", .string)
          }
          .map(.memberwise(User.Login.init))
        }
      }
    }
  }
}

extension SiteRoute.View {

  public enum SignupRoute: Equatable, Sendable {
    case index
    case submit(User.Create)

    static let rootPath = "signup"

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
      Route(.case(Self.submit)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("username", .string)
            Field("email", .string)
            Field("password", .string)
            Field("confirmPassword", .string)
          }
          .map(.memberwise(User.Create.init))
        }
      }
    }
  }
}
