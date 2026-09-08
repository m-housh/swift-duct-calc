import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute.View.UserRoute {
  public enum PathTemplateRoute: Equatable, Sendable {
    case index(Project.ID? = nil)
    case new(EquivalentLength.EffectiveLengthType, Project.ID? = nil)
    case edit(PathTemplate.ID, Project.ID? = nil)
    case importing(Project.ID? = nil)
    case previewImport(PathTemplate.Transfer)
    case save(SaveForm)
    case delete(PathTemplate.ID)
    case evaluate(TemplateFitting.EvaluationRequest)

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Method.get
        Query { Optionally { Field("project") { Project.ID.parser() } } }
      }
      Route(.case(Self.importing)) {
        Path { "import" }
        Method.get
        Query { Optionally { Field("project") { Project.ID.parser() } } }
      }
      Route(.case(Self.previewImport)) {
        Path { "import-preview" }
        Method.post
        Body(.json(PathTemplate.Transfer.self))
      }
      Route(.case(Self.new)) {
        Path {
          "new"
          EquivalentLength.EffectiveLengthType.parser()
        }
        Method.get
        Query { Optionally { Field("project") { Project.ID.parser() } } }
      }
      Route(.case(Self.evaluate)) {
        Path { "evaluate" }
        Method.post
        Body(.json(TemplateFitting.EvaluationRequest.self))
      }
      Route(.case(Self.edit)) {
        Path { PathTemplate.ID.parser() }
        Method.get
        Query { Optionally { Field("project") { Project.ID.parser() } } }
      }
      Route(.case(Self.delete)) {
        Path { PathTemplate.ID.parser() }
        Method.delete
      }
      Route(.case(Self.save)) {
        Method.post
        Body(.json(SaveForm.self))
      }
    }

    public struct SaveForm: Codable, Equatable, Sendable {
      public let id: PathTemplate.ID?
      public let revision: UUID?
      public let configuration: PathTemplate.Configuration
    }
  }
}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute {
  public enum GuidedRoute: Equatable, Sendable {
    case index(draft: String? = nil)
    case start(PathTemplate.ID, draft: String? = nil)
    case starter(EquivalentLength.EffectiveLengthType, draft: String? = nil)
    case edit(EquivalentLength.ID)
    case save(GuidedPath.SaveRequest)

    public static let router = OneOf {
      Route(.case(Self.index)) {
        Method.get
        Query { Optionally { Field("draft", .string) } }
      }
      Route(.case(Self.start)) {
        Path {
          "start"
          PathTemplate.ID.parser()
        }
        Method.get
        Query { Optionally { Field("draft", .string) } }
      }
      Route(.case(Self.starter)) {
        Path {
          "starter"
          EquivalentLength.EffectiveLengthType.parser()
        }
        Method.post
        Query { Optionally { Field("draft", .string) } }
      }
      Route(.case(Self.edit)) {
        Path {
          "edit"
          EquivalentLength.ID.parser()
        }
        Method.get
      }
      Route(.case(Self.save)) {
        Method.post
        Body(.json(GuidedPath.SaveRequest.self))
      }
    }
  }
}
