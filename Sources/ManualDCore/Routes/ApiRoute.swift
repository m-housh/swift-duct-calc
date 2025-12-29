import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute {
  /// Represents api routes.
  ///
  /// The routes return json as opposed to view routes that return html.
  public enum Api: Sendable, Equatable {

    case project(Self.ProjectRoute)

    public static let rootPath = Path {
      "api"
      "v1"
    }

    public static let router = OneOf {
      Route(.case(Self.project)) {
        rootPath
        ProjectRoute.router
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
