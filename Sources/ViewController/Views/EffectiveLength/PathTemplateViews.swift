import Elementary
import Foundation
import ManualDCore
import Styleguide

struct PathTemplatesView: HTML, Sendable {
  let templates: [PathTemplate]
  let projectID: Project.ID?
  var choosing: Bool = false

  var body: some HTML {
    Navbar(showSidebarToggle: false, isLoggedIn: true)
    div(.class("w-full p-4 space-y-6")) {
      if let projectID {
        a(.class("btn btn-ghost"), .href(effectiveLengthsURL(projectID))) { "← Back to project" }
      }
      PageTitleRow {
        PageTitle { choosing ? "Choose a path template" : "Path templates" }
        PlusButton()
          .attributes(.class("btn-primary"), .showModal(id: "newPathTemplate"))
          .tooltip("Add path template")
      }
      ModalForm(id: "newPathTemplate", dismiss: true) {
        h2(.class("text-2xl font-bold")) { "Add path template" }
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
      div(.class("flex flex-wrap gap-2")) {
        if choosing, let projectID {
          for type in EquivalentLength.EffectiveLengthType.allCases {
            if !templates.contains(where: { $0.configuration.type == type }) {
              form(.method(.post), .action("\(guidedPathURL(projectID))/starter/\(type.rawValue)"))
              {
                SubmitButton(title: "Use starter \(type.rawValue)")
              }
            }
          }
        } else if !choosing {
          a(.class("btn"), .href(pathTemplatesURL(projectID, suffix: "/import"))) {
            "Import JSON template"
          }
        }
      }
      for template in templates {
        div(.class("card bg-base-200 border border-base-300")) {
          div(.class("card-body")) {
            h2(.class("card-title")) { template.configuration.name }
            p {
              "\(template.configuration.type.rawValue.capitalized) · \(template.configuration.steps.count) sections"
            }
            div(.class("card-actions justify-end")) {
              a(.class("btn"), .href(pathTemplatesURL(projectID, suffix: "/\(template.id)"))) {
                "Configure"
              }
              if choosing, let projectID {
                a(
                  .class("btn btn-secondary"),
                  .href("\(guidedPathURL(projectID))/start/\(template.id)")
                ) {
                  "Use template"
                }
              }
            }
          }
        }
      }
      if choosing {
        a(.class("link"), .href(pathTemplatesURL(projectID))) { "Manage templates" }
      }
    }
  }
}

struct PathTemplateWorkspace: HTML, Sendable {
  struct Data: Encodable, Sendable {
    let mode: String
    let configuration: PathTemplate.Configuration
    let template: PathTemplate?
    let definitions: [Fitting.Definition]
    let projectID: Project.ID?
    let path: EquivalentLength?
    let saveURL: String
    let backURL: String
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
    Navbar(showSidebarToggle: false, isLoggedIn: true)
    div(.class("w-full p-4 space-y-4")) {
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
      script(.src("/js/path-templates.js"), .init(name: "defer", value: "")) {}
    }
  }
}

func guidedPathURL(_ projectID: Project.ID) -> String {
  SiteRoute.View.router.path(for: .project(.detail(projectID, .equivalentLength(.guided(.index)))))
}

func effectiveLengthsURL(_ projectID: Project.ID) -> String {
  SiteRoute.View.router.path(for: .project(.detail(projectID, .equivalentLength(.index))))
}

func pathTemplatesURL(_ projectID: Project.ID?, suffix: String = "") -> String {
  let base = "/path-templates\(suffix)"
  guard let projectID else { return base }
  return "\(base)?project=\(projectID)"
}
