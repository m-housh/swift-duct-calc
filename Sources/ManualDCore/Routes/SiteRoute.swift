import CasePathsCore
import FluentKit
import Foundation
@preconcurrency import URLRouting

public enum SiteRoute: Equatable, Sendable {

  case health
  case view(Self.View)

  public static let router = OneOf {
    Route(.case(Self.health)) {
      Path { "health" }
      Method.get
    }
    Route(.case(Self.view)) {
      SiteRoute.View.router
    }
  }
}
