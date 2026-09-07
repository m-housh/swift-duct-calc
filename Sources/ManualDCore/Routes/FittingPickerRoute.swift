import Foundation
@preconcurrency import URLRouting

extension SiteRoute.View {
  /// Read-only catalog preview; these endpoints do not write a project or saved path.
  public enum FittingPickerRoute: Equatable, Sendable {
    case index(Fitting.PathType)
    case configure(String)
    case evaluate(String)
    case reference(String)

    static let router = OneOf {
      Route(.case(Self.configure)) {
        Path { "configure" }
        Method.post
        Body { FormData { Field("payload", .string) } }
      }
      Route(.case(Self.evaluate)) {
        Path { "evaluate" }
        Method.post
        Body { FormData { Field("payload", .string) } }
      }
      Route(.case(Self.reference)) {
        Path { "reference" }
        Method.post
        Body { FormData { Field("payload", .string) } }
      }
      Route(.case(Self.index)) {
        Method.get
        Query { Field("type", default: Fitting.PathType.supply) { Fitting.PathType.parser() } }
      }
    }

    /// HTTP field transport only. ViewController parses these strings into Fitting.Inputs.
    public struct Submission: Codable, Equatable, Sendable {
      public let pathType: Fitting.PathType
      public let groupID: Fitting.Group.ID
      public let fittingID: Fitting.ID
      public let fields: [String: String]
    }

    public struct ReferenceSubmission: Codable, Equatable, Sendable {
      public let pathType: Fitting.PathType
      public let code: String
      public let length: String
    }
  }
}
