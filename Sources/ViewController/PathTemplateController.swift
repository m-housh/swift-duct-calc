import DatabaseClient
import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDCore
import ProjectClient
import Styleguide

private func allFittings() async throws -> [TemplateFitting.Definition] {
  @Dependency(\.templateFittingClient) var fittings
  var definitions = try await fittings.fittings(.supply)
  let ids = Set(definitions.map(\.id))
  definitions += try await fittings.fittings(.return).filter { !ids.contains($0.id) }
  return definitions
}

extension SiteRoute.View.UserRoute.PathTemplateRoute {
  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.database.pathTemplates) var templates
    @Dependency(\.projectClient) var project
    @Dependency(\.templateFittingClient) var fittings
    do {
      let user = try request.currentUser()
      let projectID: Project.ID?
      switch self {
      case .index(let id), .new(_, let id), .edit(_, let id), .importing(let id): projectID = id
      default: projectID = nil
      }
      if let projectID {
        @Dependency(\.database.projects) var projects
        guard try await projects.getForUser(projectID, user.id) != nil else {
          throw NotFoundError()
        }
      }
      switch self {
      case .index:
        let saved = try await templates.fetch(user.id)
        return await request.view { PathTemplatesView(templates: saved, projectID: projectID) }
      case .new(let type, _):
        var configuration = PathTemplate.defaultConfigurations().first { $0.type == type }!
        configuration.name = "New \(type.rawValue) template"
        let workspace = try await PathTemplateWorkspace(
          data: .init(
            mode: "editor", configuration: configuration, template: nil,
            definitions: allFittings(), projectID: projectID, path: nil,
            saveURL: "/path-templates", backURL: pathTemplatesURL(projectID)
          ))
        return await request.view { workspace }
      case .edit(let id, _):
        guard let template = try await templates.get(user.id, id) else { throw NotFoundError() }
        let workspace = try await PathTemplateWorkspace(
          data: .init(
            mode: "editor", configuration: template.configuration, template: template,
            definitions: allFittings(), projectID: projectID, path: nil,
            saveURL: "/path-templates", backURL: pathTemplatesURL(projectID)
          ))
        return await request.view { workspace }
      case .importing:
        let workspace = try await PathTemplateWorkspace(
          data: .init(
            mode: "import", configuration: .init(name: "", type: .supply, steps: []), template: nil,
            definitions: allFittings(), projectID: projectID, path: nil,
            saveURL: "/path-templates", backURL: pathTemplatesURL(projectID)))
        return await request.view { workspace }
      case .previewImport(let file):
        let configuration = try file.configuration()
        try await fittings.validateTemplate(configuration)
        let json = String(decoding: try JSONEncoder().encode(configuration), as: UTF8.self)
          .replacingOccurrences(of: "<", with: "\\u003c")
          .replacingOccurrences(of: ">", with: "\\u003e")
          .replacingOccurrences(of: "&", with: "\\u0026")
        return script(.id("import-preview-data"), .init(name: "type", value: "application/json")) {
          HTMLRaw(json)
        }
      case .save(let form):
        let template: PathTemplate
        if let id = form.id {
          guard let revision = form.revision else { throw PathTemplateConflictError() }
          template = try await project.updatePathTemplate(
            userID: user.id, id: id, revision: revision, configuration: form.configuration
          )
        } else {
          template = try await project.createPathTemplate(
            userID: user.id, configuration: form.configuration)
        }
        return div(.data("redirect", value: "/path-templates/\(template.id)")) { "Template saved." }
      case .delete(let id):
        try await templates.delete(user.id, id)
        return div(.data("redirect", value: "/path-templates")) { "Template deleted." }
      case .evaluate(let evaluation):
        switch try await fittings.evaluate(evaluation) {
        case .resolved(let result):
          return div(.data("feet", value: "\(result.equivalentLengthFeet)")) {
            "\(result.equivalentLengthFeet) ft"
          }
        case .unresolved(let message): return workspaceError(message)
        }
      }
    } catch {
      let failure = workspaceError(error)
      switch self {
      case .index, .new, .edit, .importing:
        return await request.view {
          div(.class("max-w-5xl mx-auto p-4 space-y-4")) {
            failure
            a(.class("link"), .href("/path-templates")) { "Back to templates" }
          }
        }
      default: return failure
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute.GuidedRoute {
  func renderView(on request: ViewController.Request, projectID: Project.ID) async
    -> AnySendableHTML
  {
    @Dependency(\.database) var database
    @Dependency(\.projectClient) var project
    do {
      let user = try request.currentUser()
      guard try await database.projects.getForUser(projectID, user.id) != nil else {
        throw NotFoundError()
      }
      switch self {
      case .index(let draft):
        let initialValues = try draft.map(GuidedPath.InitialValues.init(draft:))
        let templates = try await database.pathTemplates.fetch(user.id)
        return await request.view {
          PathTemplatesView(
            templates: templates, projectID: projectID, choosing: true, draft: draft,
            preferredType: initialValues?.type)
        }
      case .start(let id, let draft):
        guard let template = try await database.pathTemplates.get(user.id, id) else {
          throw NotFoundError()
        }
        return try await workspace(
          on: request, projectID: projectID, template: template, draft: draft)
      case .edit(let id):
        return await SiteRoute.View.ProjectRoute.EquivalentLengthRoute.editor(id)
          .renderPathEditor(on: request, projectID: projectID)
      case .save(let form):
        _ = try await project.saveGuidedPath(userID: user.id, projectID: projectID, request: form)
        return div(.data("redirect", value: effectiveLengthsURL(projectID))) { "Path saved." }
      }
    } catch {
      let failure = workspaceError(error)
      if case .save = self { return failure }
      return await request.view {
        div(.class("max-w-5xl mx-auto p-4 space-y-4")) {
          failure
          a(.class("link"), .href(effectiveLengthsURL(projectID))) { "Back to paths" }
        }
      }
    }
  }

  private func workspace(
    on request: ViewController.Request, projectID: Project.ID, template: PathTemplate,
    draft: String?
  )
    async throws -> AnySendableHTML
  {
    @Dependency(\.templateFittingClient) var fittings
    try await fittings.validateTemplate(template.configuration)
    let view = try await PathTemplateWorkspace(
      data: .init(
        mode: "path", configuration: template.configuration, template: template,
        definitions: allFittings(), projectID: projectID, path: nil,
        saveURL: guidedPathURL(projectID), backURL: effectiveLengthsURL(projectID),
        initialValues: draft.map(GuidedPath.InitialValues.init(draft:))
      ))
    return await request.view { view }
  }
}

private func workspaceError(_ message: String) -> some HTML & Sendable {
  div(.class("alert alert-error"), .data("workspace-error", value: message)) { message }
}

private func workspaceError(_ error: any Error) -> some HTML & Sendable {
  if let error = error as? ValidationError { return workspaceError(error.message) }
  if error is NotFoundError {
    return workspaceError("This project, path, or template is unavailable.")
  }
  if error is GuidedPath.InitialValuesError {
    return workspaceError("Check the path name and straight duct lengths.")
  }
  if let error = error as? PathConflictError { return workspaceError(error.message) }
  if error is PathTemplateConflictError {
    return workspaceError(
      "This template changed in another tab. Your edits are still here; duplicate them or reload the saved template."
    )
  }
  if let error = error as? PathTemplate.ConfigurationError, error == .unsupportedVersion {
    return workspaceError(
      "This template file format or version is not supported. Nothing was imported.")
  }
  if let error = error as? TemplateFittingClient.TemplateValidationError {
    return workspaceError(error.message)
  }
  if error is PathTemplate.ConfigurationError {
    return workspaceError(
      "Check section names, fitting choices, defaults, and supply/return compatibility.")
  }
  return workspaceError("Unable to save or load this item. Your changes are still here; try again.")
}
