import Elementary
import ElementaryHTMX
import Foundation
import ManualDCore
import Styleguide

struct FrictionRateTemplatesView: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  static let id = "frictionRateTemplates"
  let projectID: Project.ID
  let hasComponents: Bool

  private func shortcut(for template: FrictionRateTemplate) -> KeybindingAction {
    switch template {
    case .shared: .templateShared
    case .furnace: .templateFurnace
    case .airHandler: .templateAirHandler
    }
  }

  var body: some HTML {
    ModalForm(id: Self.id, title: "Choose a system template", dismiss: true) {
      div(.class("space-y-4")) {
        p(.class("muted")) {
          "Start with common component losses, then edit them to match your equipment. Values are in inches of water column."
        }
        p(.class("muted")) {
          "After applying a template, add a filter from your library or skip that step. The shortcuts below apply a template while this chooser is open."
        }
        if hasComponents {
          Alert {
            "Using a template replaces all current component losses, including custom components and edited values."
          }
        }
        for template in FrictionRateTemplate.allCases {
          div(.class("card bg-base-200 border border-base-300")) {
            div(.class("card-body")) {
              div(.class("template-card-heading")) {
                h3(.class("card-title")) { template.name }
                // A block wrapper keeps Elementary's formatted snapshots from moving inline text.
                div(.class("template-card-shortcut")) {
                  kbd(.class("kbd kbd-sm")) { bindings.label(shortcut(for: template)) }
                }
              }
              dl {
                for component in template.components(projectID: projectID) {
                  div(.class("flex justify-between gap-4")) {
                    dt { component.name.replacingOccurrences(of: "-", with: " ").capitalized }
                    dd { String(format: "%.2f", component.value) }
                  }
                }
              }
              div(.class("card-actions justify-end")) {
                form(
                  .hx.post(
                    route: .project(.detail(projectID, .frictionRate(.applyTemplate(template))))),
                  .hx.target("body"), .hx.swap(.outerHTML),
                  .data("success-message", value: "System template applied."),
                  .hx.disabledElt("find button")
                ) {
                  button(
                    .type(.submit), .class("btn btn-secondary"),
                    .init(
                      name: "aria-keyshortcuts",
                      value: bindings[shortcut(for: template)]),
                    .init(name: "aria-label", value: "Use \(template.name) template")
                  ) { "Use template" }
                }
              }
            }
          }
        }
      }
    }
  }
}
