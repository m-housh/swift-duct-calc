import Elementary
import ManualDCore
import Styleguide

struct ProjectShortcutsDialog: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings

  typealias Tab = SiteRoute.View.ProjectRoute.DetailRoute.Tab
  static let id = "projectShortcuts"
  let activeTab: Tab
  var hasStepActions = true

  private var pages: [Tab] {
    [.project, .rooms, .equipment, .equivalentLength, .frictionRate, .ductSizing]
  }

  var body: some HTML {
    ModalForm(id: Self.id, title: "Keyboard shortcuts", dismiss: true) {
      if hasStepActions {
        ProjectPageShortcuts(page: activeTab, current: true)
      } else {
        p(.class("text-sm mt-2")) {
          "Only navigation shortcuts are available on this page."
        }
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "Project navigation" }
        tbody {
          ProjectShortcutRow("Next project step", action: .nextStep)
          ProjectShortcutRow("Previous project step", action: .previousStep)
          ProjectShortcutRow("Project", action: .project)
          ProjectShortcutRow("Rooms", action: .rooms)
          ProjectShortcutRow("Equipment", action: .equipment)
          ProjectShortcutRow("Total effective length", action: .effectiveLength)
          ProjectShortcutRow("Friction rate", action: .frictionRate)
          ProjectShortcutRow("Duct sizes", action: .ductSizes)
        }
      }
      p(.class("text-sm mt-2")) {
        "Next and previous follow sidebar order and stop at either end."
      }
      table(.class("table table-sm mt-4")) {
        caption(.class("text-left font-bold p-2")) { "App navigation" }
        tbody {
          ProjectShortcutRow("Ductulator", action: .ductulator)
          ProjectShortcutRow("Fitting reference", action: .fittings)
          ProjectShortcutRow("Projects", action: .projects)
          ProjectShortcutRow("Profile", action: .profile)
        }
      }
      details(.class("mt-4")) {
        summary(.class("font-bold cursor-pointer")) { "Other project pages" }
        for page in pages.filter({ $0 != activeTab }) {
          ProjectPageShortcuts(page: page)
        }
      }
      p(.class("text-sm mt-4")) {
        "Press \(bindings.label(.reveal)) to reveal shortcuts on the page, or \(bindings.label(.help)) to open this help. Customize shortcuts in Account → Keybindings. Ductulator and fitting reference open in new tabs. Shortcuts work in search boxes and pause in other fields or open dialogs."
      }
    }
  }

}

private struct ProjectPageShortcuts: HTML, Sendable {
  typealias Tab = ProjectShortcutsDialog.Tab
  let page: Tab
  var current = false

  private func title(_ page: Tab) -> String {
    switch page {
    case .project: "Project"
    case .rooms: "Rooms"
    case .equipment: "Equipment"
    case .equivalentLength: "Total effective length"
    case .frictionRate: "Friction rate"
    case .ductSizing: "Duct sizes"
    }
  }

  var body: some HTML {
    table(.class("table table-sm mt-4")) {
      caption(.class("text-left font-bold p-2")) {
        current ? "On this page · \(title(page))" : title(page)
      }
      tbody {
        switch page {
        case .project:
          ProjectShortcutRow("Project details", action: .primaryAction)
        case .rooms:
          ProjectShortcutRow("Add room", action: .primaryAction)
          ProjectShortcutRow("Import loads", action: .importLoads)
          ProjectShortcutRow("Find a room", action: .search)
          ProjectShortcutRow("Next room row", action: .nextRoom)
          ProjectShortcutRow("Previous room row", action: .previousRoom)
        case .equipment:
          ProjectShortcutRow("Edit all", action: .primaryAction)
          ProjectShortcutRow("Heating airflow", action: .heating)
          ProjectShortcutRow("Cooling airflow", action: .cooling)
          ProjectShortcutRow("Static pressure", action: .pressure)
        case .equivalentLength:
          ProjectShortcutRow("Add return", action: .addReturn)
          ProjectShortcutRow("Add supply", action: .addSupply)
          ProjectShortcutRow("Add path", action: .primaryAction)
        case .frictionRate:
          ProjectShortcutRow("Use template", action: .primaryAction)
        case .ductSizing:
          ProjectShortcutRow("Add trunk", action: .primaryAction)
          ProjectShortcutRow("Export PDF", action: .exportPDF)
          ProjectShortcutRow("Find a register", action: .search)
        }
      }
    }
  }

}

private struct ProjectShortcutRow: HTML, Sendable {
  @Environment(ShortcutViewValue.$bindings) private var bindings
  let label: String
  let action: KeybindingAction

  init(_ label: String, action: KeybindingAction) {
    self.label = label
    self.action = action
  }

  var body: some HTML<HTMLTag.tr> {
    tr {
      th(.init(name: "scope", value: "row")) { label }
      td(.class("text-right")) {
        Keycaps(bindings[action])

      }
    }
  }
}
