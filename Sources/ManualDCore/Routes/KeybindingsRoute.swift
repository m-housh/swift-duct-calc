import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute.View.UserRoute {
  public enum KeybindingsRoute: Equatable, Sendable {
    case index
    case save(String)

    public static let router = OneOf {
      Route(.case(Self.index)) { Method.get }
      Route(.case(Self.save)) {
        Method.post
        Body { SafeFormData { Field("bindings", .string) } }
      }
    }
  }
}
