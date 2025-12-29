import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute {
  /// Represents api routes.
  ///
  /// The routes return json as opposed to view routes that return html.
  public enum Api {
    public static let rootPath = Path {
      "api"
      "v1"
    }

  }

}
