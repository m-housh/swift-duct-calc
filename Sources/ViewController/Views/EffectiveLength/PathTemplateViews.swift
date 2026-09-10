import Elementary
import Foundation
import ManualDCore
import Styleguide

struct PathTemplatesView: HTML, Sendable {
  let templates: [PathTemplate]
  let projectID: Project.ID?
  var choosing: Bool = false
  var draft: String? = nil
  var preferredType: EquivalentLength.EffectiveLengthType? = nil

  var body: some HTML {
    Navbar(isLoggedIn: true)
    div(.id("path-template-list"), .class("w-full p-4 space-y-6")) {
      link(.rel(.stylesheet), .href("/css/path-template-chooser.css?v=1"))
      if let projectID {
        a(.class("btn btn-ghost"), .href(effectiveLengthsURL(projectID))) { "← Back to project" }
      }
      PageTitleRow {
        PageTitle { choosing ? "Choose a path template" : "Path templates" }
        PlusButton("Add path template")
          .attributes(.class("btn-primary"), .showModal(id: "newPathTemplate"))
          .tooltip("Add path template")
      }
      ModalForm(id: "newPathTemplate", title: "Add path template", dismiss: true) {
        div(.class("space-y-3 mt-4")) {
          for type in EquivalentLength.EffectiveLengthType.allCases {
            a(
              .class("btn btn-primary w-full"),
              .href(pathTemplatesURL(projectID, suffix: "/new/\(type.rawValue)"))
            ) {
              "New \(type.rawValue) template"
            }
          }
          a(.class("btn w-full"), .href(pathTemplatesURL(projectID, suffix: "/import"))) {
            "Import JSON template"
          }
        }
      }
      p { "Use your usual fittings, with the choices and defaults you prefer." }
      if choosing, let projectID {
        for type in orderedTypes {
          section(
            .class("template-choice-section space-y-4"),
            .data("template-type", value: type.rawValue),
            .data("template-preferred", value: String(type == preferredType))
          ) {
            div(.class("template-choice-heading")) {
              h2(.class("text-xl font-bold")) { "\(type.rawValue.capitalized) templates" }
              if type == preferredType {
                span(.class("template-choice-match")) { "Matches your \(type.rawValue) path" }
              }
            }
            if !templates.contains(where: { $0.configuration.type == type }) {
              PathTemplateCard(
                title: "Starter \(type.rawValue) path",
                summary:
                  "A ready-to-use set of \(type.rawValue) fittings. Adjust it as you build your path.",
                configureURL: nil,
                useURL: withDraft("\(guidedPathURL(projectID))/starter/\(type.rawValue)"),
                starterType: type, emphasized: preferredType == nil || type == preferredType)
            }
            for template in templates where template.configuration.type == type {
              templateCard(template)
            }
          }
        }
      } else {
        a(.class("btn"), .href(pathTemplatesURL(projectID, suffix: "/import"))) {
          "Import JSON template"
        }
        for template in templates { templateCard(template) }
      }
      if choosing {
        a(.class("link"), .href(pathTemplatesURL(projectID))) { "Manage templates" }
      }
    }
  }

  private var orderedTypes: [EquivalentLength.EffectiveLengthType] {
    guard let preferredType else { return EquivalentLength.EffectiveLengthType.allCases }
    return [preferredType]
      + EquivalentLength.EffectiveLengthType.allCases.filter { $0 != preferredType }
  }

  private func templateCard(_ template: PathTemplate) -> PathTemplateCard {
    .init(
      title: template.configuration.name,
      summary:
        "\(template.configuration.type.rawValue.capitalized) · \(template.configuration.steps.count) sections",
      configureURL: pathTemplatesURL(projectID, suffix: "/\(template.id)"),
      useURL: choosing
        ? projectID.map { withDraft("\(guidedPathURL($0))/start/\(template.id)") } : nil,
      emphasized: preferredType == nil || template.configuration.type == preferredType)
  }

  private func withDraft(_ path: String) -> String {
    guard let draft else { return path }
    var url = URLComponents()
    url.path = path
    url.queryItems = [.init(name: "draft", value: draft)]
    url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return url.string!
  }
}

private struct PathTemplateCard: HTML, Sendable {
  let title: String
  let summary: String
  let configureURL: String?
  let useURL: String?
  var starterType: EquivalentLength.EffectiveLengthType? = nil
  var emphasized: Bool = true

  private var actionClass: String { emphasized ? "btn btn-secondary" : "btn btn-outline" }

  var body: some HTML {
    div(.class("card bg-base-200 border border-base-300")) {
      div(.class("card-body")) {
        h3(.class("card-title")) { title }
        p { summary }
        div(.class("card-actions justify-end")) {
          if let configureURL {
            a(.class("btn btn-ghost"), .href(configureURL)) { "Configure" }
          }
          if let useURL {
            if let starterType {
              form(.method(.post), .action(useURL)) {
                button(.type(.submit), .class(actionClass)) {
                  "Use starter \(starterType.rawValue)"
                }
              }
            } else {
              a(.class(actionClass), .href(useURL)) { "Use template" }
            }
          }
        }
      }
    }
  }
}

struct PathTemplateWorkspace: HTML, Sendable {
  struct Data: Encodable, Sendable {
    let mode: String
    let configuration: PathTemplate.Configuration
    let template: PathTemplate?
    let definitions: [TemplateFitting.Definition]
    let projectID: Project.ID?
    let path: EquivalentLength?
    let saveURL: String
    let backURL: String
    var initialValues: GuidedPath.InitialValues? = nil
  }
  let data: Data
  let encoded: String

  init(data: Data) throws {
    self.data = data
    self.encoded = String(decoding: try JSONEncoder().encode(data), as: UTF8.self)
      .replacingOccurrences(of: "<", with: "\\u003c")
      .replacingOccurrences(of: ">", with: "\\u003e")
      .replacingOccurrences(of: "&", with: "\\u0026")
  }

  var body: some HTML {
    Navbar(isLoggedIn: true)
    div(.id("path-template-page"), .class("w-full p-4 space-y-4")) {
      div(.class("flex flex-wrap items-center gap-2")) {
        if data.mode != "path", let projectID = data.projectID {
          a(.class("btn btn-ghost"), .href(effectiveLengthsURL(projectID))) { "← Back to project" }
        }
        a(.class("btn btn-ghost"), .href(data.backURL)) {
          "Back to \(data.mode != "path" ? "templates" : "paths")"
        }
      }
      div(.id("path-template-workspace"), .class("space-y-4")) {
        PageTitle { data.mode == "editor" ? "Configure template" : "Build path" }
        p { "Loading fittings…" }
      }
      noscript { p { "The guided editor needs JavaScript. Manual path entry remains available." } }
      script(.id("path-template-data"), .init(name: "type", value: "application/json")) {
        HTMLRaw(encoded)
      }
      script(.src("/js/path-templates.js?v=path-revisions-3"), .init(name: "defer", value: "")) {}
    }
  }
}

func guidedPathURL(_ projectID: Project.ID) -> String {
  SiteRoute.View.router.path(
    for: .project(.detail(projectID, .equivalentLength(.guided(.index())))))
}

func effectiveLengthsURL(_ projectID: Project.ID) -> String {
  SiteRoute.View.router.path(for: .project(.detail(projectID, .equivalentLength(.index))))
}

func pathTemplatesURL(_ projectID: Project.ID?, suffix: String = "") -> String {
  let base = "/path-templates\(suffix)"
  guard let projectID else { return base }
  return "\(base)?project=\(projectID)"
}
