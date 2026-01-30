import Foundation
import ManualDCore

public struct ProjectClientError: Error {
  public let reason: String

  public init(_ reason: String) {
    self.reason = reason
  }

  static func notFound(_ notFound: NotFound) -> Self {
    .init(notFound.reason)
  }

  enum NotFound {
    case project(Project.ID)
    case frictionRate(Project.ID)

    var reason: String {
      switch self {
      case .project(let id):
        return "Project not found. id: \(id)"
      case .frictionRate(let id):
        return """
          Friction unable to be calculated. id: \(id)

          This usually means that not all the required steps have been completed.

          Calculating the friction rate requires the component pressure losses to be set and
          have a max equivalent length for both the supply and return.
          """
      }
    }
  }
}
