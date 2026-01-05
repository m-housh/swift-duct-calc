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
    // case frictionRate(FrictionRateRoute)
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
      // Route(.case(Self.frictionRate)) {
      //   SiteRoute.View.FrictionRateRoute.router
      // }
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
    case detail(Project.ID, DetailRoute)
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
      Route(.case(Self.detail)) {
        Path {
          rootPath
          Project.ID.parser()
        }
        DetailRoute.router
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

extension SiteRoute.View.ProjectRoute {

  public enum DetailRoute: Equatable, Sendable {
    case index
    case frictionRate(FrictionRateRoute)
    case rooms(RoomRoute)

    static let router = OneOf {
      Route(.case(Self.index)) {
        Method.get
      }
      Route(.case(Self.frictionRate)) {
        FrictionRateRoute.router
      }
      Route(.case(Self.rooms)) {
        RoomRoute.router
      }
    }
  }

  public enum RoomRoute: Equatable, Sendable {
    case form(dismiss: Bool = false)
    case index
    case submit(Room.Form)

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
        Path {
          rootPath
        }
        Method.get
      }
      Route(.case(Self.submit)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("name", .string)
            Field("heatingLoad") { Double.parser() }
            Field("coolingLoad") { Double.parser() }
            Field("registerCount") { Digits() }
          }
          .map(.memberwise(Room.Form.init))
        }
      }
    }
  }

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

    public enum FormType: String, CaseIterable, Codable, Equatable, Sendable {
      case equipmentInfo
      case componentPressureLoss
    }
  }
}

extension SiteRoute.View {
  public enum EffectiveLengthRoute: Equatable, Sendable {
    case field(FieldType, style: EffectiveLength.EffectiveLengthType? = nil)
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
          Optionally {
            Field("style", default: nil) {
              EffectiveLength.EffectiveLengthType.parser()
            }
          }
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

  public enum FormStep: String, CaseIterable, Equatable, Sendable {
    case nameAndType
    case straightLengths
    case groups
  }
}

extension SiteRoute.View {

  public enum LoginRoute: Equatable, Sendable {
    case index(next: String? = nil)
    case submit(User.Login)

    static let rootPath = "login"

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
        Query {
          Optionally {
            Field("next", default: nil) {
              CharacterSet.urlPathAllowed.map(.string)
            }
          }
        }
      }
      Route(.case(Self.submit)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("email", .string)
            Field("password", .string)
            Optionally {
              Field("next", default: nil) {
                CharacterSet.urlPathAllowed.map(.string)
              }
            }
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
