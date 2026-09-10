import Elementary
import Styleguide

struct ProjectShortcutsDialog: HTML, Sendable {
  static let id = "projectShortcuts"
  static let titleID = "project-shortcuts-title"

  var body: some HTML {
    ModalForm(id: Self.id, dismiss: true) {
      h2(.id(Self.titleID), .class("text-lg font-bold")) { "Keyboard shortcuts" }
      p(.class("text-sm mt-2")) { "Hold Ctrl+Alt and press a key below." }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold text-primary p-2")) { "Project sections" }
        tbody {
          row("Project", key: "1")
          row("Rooms", key: "2")
          row("Equipment", key: "3")
          row("T.E.L.", key: "4")
          row("Friction Rate", key: "5")
          row("Duct Sizes", key: "6")
          row("Next section", key: "J")
          row("Previous section", key: "K")
        }
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold text-primary p-2")) { "App navigation" }
        tbody {
          row("Ductulator", key: "D")
          row("Fitting reference", key: "F")
          row("Projects", key: "P")
          row("Profile", key: "U")
        }
      }
      p(.class("text-sm mt-2")) {
        "Ductulator and fitting reference open in new tabs. Shortcuts pause while editing a field or when a dialog is open."
      }
    }
    .attributes(.init(name: "aria-labelledby", value: Self.titleID))
  }

  private func row(_ label: String, key: String) -> some HTML<HTMLTag.tr> & Sendable {
    tr {
      th(.init(name: "scope", value: "row")) { label }
      td(.class("text-right")) { kbd(.class("kbd kbd-sm")) { key } }
    }
  }
}
