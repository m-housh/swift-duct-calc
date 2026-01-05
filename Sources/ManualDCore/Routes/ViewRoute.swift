import CasePathsCore
import FluentKit
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
    case effectiveLength(EffectiveLengthRoute)

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
      Route(.case(Self.effectiveLength)) {
        SiteRoute.View.EffectiveLengthRoute.router
      }
    }
  }
}

extension SiteRoute.View {
  public enum ProjectRoute: Equatable, Sendable {
    case create(Project.Create)
    case delete(id: Project.ID)
    case detail(Project.ID, DetailRoute)
    case form(id: Project.ID? = nil, dismiss: Bool = false)
    case index
    case page(PageRequest)
    case update(Project.Update)

    public static func page(page: Int, per limit: Int) -> Self {
      .page(.init(page: page, per: limit))
    }

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
      Route(.case(Self.delete)) {
        Path {
          rootPath
          Project.ID.parser()
        }
        Method.delete
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
          Optionally {
            Field("id", default: nil) { Project.ID.parser() }
          }
          Field("dismiss", default: false) { Bool.parser() }
        }
      }
      Route(.case(Self.index)) {
        Path { rootPath }
        Method.get
      }
      Route(.case(Self.page)) {
        Path {
          rootPath
          "page"
        }
        Method.get
        Query {
          Field("page", default: 1) { Int.parser() }
          Field("per", default: 25) { Int.parser() }
        }
        .map(.memberwise(PageRequest.init))
      }
      Route(.case(Self.update)) {
        Path { rootPath }
        Method.patch
        Body {
          FormData {
            Field("id") { Project.ID.parser() }
            Optionally {
              Field("name", .string)
            }
            Optionally {
              Field("streetAddress", .string)
            }
            Optionally {
              Field("city", .string)
            }
            Optionally {
              Field("state", .string)
            }
            Optionally {
              Field("zipCode", .string)
            }
          }
          .map(.memberwise(Project.Update.init))
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute {

  public enum DetailRoute: Equatable, Sendable {
    case index(tab: Tab = .default)
    case equipment(EquipmentInfoRoute)
    case frictionRate(FrictionRateRoute)
    case rooms(RoomRoute)

    static let router = OneOf {
      Route(.case(Self.index)) {
        Method.get
        Query {
          Field("tab", default: Tab.default) {
            Tab.parser()
          }
        }
      }
      Route(.case(Self.equipment)) {
        EquipmentInfoRoute.router
      }
      Route(.case(Self.frictionRate)) {
        FrictionRateRoute.router
      }
      Route(.case(Self.rooms)) {
        RoomRoute.router
      }
    }

    public enum Tab: String, CaseIterable, Equatable, Sendable {
      case project
      case rooms
      case effectiveLength
      case frictionRate
      case ductSizing

      public static var `default`: Self { .rooms }
    }
  }

  public enum RoomRoute: Equatable, Sendable {
    case delete(id: Room.ID)
    case form(id: Room.ID? = nil, dismiss: Bool = false)
    case index
    case submit(Room.Form)
    case update(Room.Update)

    static let rootPath = "rooms"

    public static let router = OneOf {
      Route(.case(Self.delete)) {
        Path {
          rootPath
          Room.ID.parser()
        }
        Method.delete
      }
      Route(.case(Self.form)) {
        Path {
          rootPath
          "create"
        }
        Method.get
        Query {
          Optionally {
            Field("id", default: nil) { Room.ID.parser() }
          }
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
      Route(.case(Self.update)) {
        Path { rootPath }
        Method.patch
        Body {
          FormData {
            Field("id") { Room.ID.parser() }
            Optionally {
              Field("name", .string)
            }
            Optionally {
              Field("heatingLoad") { Double.parser() }
            }
            Optionally {
              Field("coolingLoad") { Double.parser() }
            }
            Optionally {
              Field("registerCount") { Digits() }
            }
          }
          .map(.memberwise(Room.Update.init))
        }
      }
    }
  }

  public enum FrictionRateRoute: Equatable, Sendable {
    case index
    // TODO: Remove form or move equipment / component losses routes here.
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

  public enum EquipmentInfoRoute: Equatable, Sendable {
    case index
    case form(dismiss: Bool)
    case submit(EquipmentInfo.Create)
    case update(EquipmentInfo.Update)

    static let rootPath = "equipment"

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
          Field("dismiss", default: true) { Bool.parser() }
        }
      }
      Route(.case(Self.submit)) {
        Path { rootPath }
        Method.post
        Body {
          FormData {
            Field("projectID") { Project.ID.parser() }
            Field("staticPressure") { Double.parser() }
            Field("heatingCFM") { Int.parser() }
            Field("coolingCFM") { Int.parser() }
          }
          .map(.memberwise(EquipmentInfo.Create.init))
        }
      }
      Route(.case(Self.update)) {
        Path { rootPath }
        Method.patch
        Body {
          FormData {
            Field("id") { EquipmentInfo.ID.parser() }
            Optionally {
              Field("staticPressure", default: nil) { Double.parser() }
            }
            Optionally {
              Field("heatingCFM", default: nil) { Int.parser() }
            }
            Optionally {
              Field("coolingCFM", default: nil) { Int.parser() }
            }
          }
          .map(.memberwise(EquipmentInfo.Update.init))
        }
      }
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

extension PageRequest: @retroactive Equatable {
  public static func == (lhs: FluentKit.PageRequest, rhs: FluentKit.PageRequest) -> Bool {
    lhs.page == rhs.page && lhs.per == rhs.per
  }
}
