import Elementary
import ManualDCore
import Styleguide

struct FittingsShortcutsDialog: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  static let id = "fittingsShortcuts"
  let isLoggedIn: Bool

  var body: some HTML {
    ModalForm(id: Self.id, title: "Keyboard shortcuts", dismiss: true) {
      p(.class("text-sm mt-2")) {
        "Press \(bindings.label(.reveal)) to reveal shortcuts on the page, or \(bindings.label(.help)) to open this help. Press \(bindings.label(.search)) to focus search. Customize shortcuts in Account → Keybindings."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "Group navigation" }
        tbody {
          for action in KeybindingAction.allCases.filter({ $0.rawValue.hasPrefix("group") }) {
            tr {
              th(.init(name: "scope", value: "row")) { action.title }
              td(.class("text-right")) { Keycaps(bindings[action]) }
            }
          }
          row("Next group", action: .nextGroup)
          row("Previous group", action: .previousGroup)
        }
      }
      p(.class("text-sm mt-2")) {
        "Group shortcuts select a group. Next and previous follow the current air path filter, including All groups, and stop at either end."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "Fitting navigation" }
        tbody {
          row("Next fitting", action: .nextFitting)
          row("Previous fitting", action: .previousFitting)
        }
      }
      p(.class("text-sm mt-2")) {
        "Next and previous move through the filtered fitting list and stop at either end."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "App navigation" }
        tbody {
          row("Ductulator", action: .ductulator)
          if isLoggedIn {
            row("Projects", action: .projects)
            row("Profile", action: .profile)
          }
        }
      }
      p(.class("text-sm mt-2")) {
        "Ductulator opens in a new tab. Shortcuts work in search boxes and pause in other fields or open dialogs."
      }
    }
  }

  private func row(_ label: String, action: KeybindingAction) -> some HTML & Sendable {
    tr {
      th(.init(name: "scope", value: "row")) { label }
      td(.class("text-right")) { Keycaps(bindings[action]) }
    }
  }
}
