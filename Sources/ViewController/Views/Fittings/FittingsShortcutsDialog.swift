import Elementary
import Styleguide

struct FittingsShortcutsDialog: HTML, Sendable {
  static let id = "fittingsShortcuts"
  let isLoggedIn: Bool

  var body: some HTML {
    ModalForm(id: Self.id, title: "Keyboard shortcuts", dismiss: true) {
      p(.class("text-sm mt-2")) {
        "Press Ctrl+K to focus search. For navigation, hold Ctrl+Alt and press a key below."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "Group navigation" }
        tbody {
          row("Groups 1–9", key: "1–9")
          row("Group 10", key: "0")
          row("Next group", key: "N")
          row("Previous group", key: "P")
        }
      }
      p(.class("text-sm mt-2")) {
        "Number keys select a group. N and P follow the current air path filter, including All groups, and stop at either end."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "Fitting navigation" }
        tbody {
          row("Next fitting", key: "J")
          row("Previous fitting", key: "K")
        }
      }
      p(.class("text-sm mt-2")) {
        "J and K move through the filtered fitting list and stop at either end."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "App navigation" }
        tbody {
          row("Ductulator", key: "D")
          if isLoggedIn {
            row("Profile", key: "U")
          }
        }
      }
      p(.class("text-sm mt-2")) {
        "Ductulator opens in a new tab. Shortcuts pause while editing a field or when a dialog is open."
      }
    }
  }

  private func row(_ label: String, key: String) -> some HTML<HTMLTag.tr> & Sendable {
    tr {
      th(.init(name: "scope", value: "row")) { label }
      td(.class("text-right")) { kbd(.class("kbd kbd-sm")) { key } }
    }
  }
}
