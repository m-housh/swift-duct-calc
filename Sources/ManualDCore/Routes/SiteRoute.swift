import CasePathsCore
import Foundation
@preconcurrency import URLRouting

public enum SiteRoute: Equatable, Sendable {

  case api(Self.Api)

  public static let router = OneOf {
    Route(.case(Self.api)) {
      SiteRoute.Api.router
    }
  }
}
