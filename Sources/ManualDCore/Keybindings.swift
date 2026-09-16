import Foundation

public enum KeybindingAction: String, CaseIterable, Codable, Sendable {
  case reveal, help, search, projects, profile, ductulator, fittings
  case project, rooms, equipment, effectiveLength, frictionRate, ductSizes
  case nextStep, previousStep, primaryAction
  case nextRoom, previousRoom, importLoads
  case addReturn, addSupply
  case exportPDF
  case heating, cooling, pressure
  case templateShared, templateFurnace, templateAirHandler
  case group1, group2, group3, group4, group5, group6, group7, group8, group9, group10
  case nextGroup, previousGroup, nextFitting, previousFitting
  case fittingLeft, fittingDown, fittingUp, fittingRight

  private var description: (String, String) {
    switch self {
    case .reveal: ("Reveal shortcuts", "/")
    case .help: ("Keyboard shortcuts", "Shift+/")
    case .search: ("Focus search", "K")
    case .projects: ("Projects", "P")
    case .profile: ("Profile", "U")
    case .ductulator: ("Ductulator", "D")
    case .fittings: ("Fitting reference", "F")
    case .project: ("Project overview", "1")
    case .rooms: ("Rooms", "2")
    case .equipment: ("Equipment", "3")
    case .effectiveLength: ("Total effective length", "4")
    case .frictionRate: ("Friction rate", "5")
    case .ductSizes: ("Duct sizes", "6")
    case .nextStep: ("Next project step", "Enter")
    case .previousStep: ("Previous project step", "Shift+Enter")
    case .primaryAction: ("Current step action", "A")
    case .importLoads: ("Import loads", "I")
    case .nextRoom: ("Next room row", "J")
    case .previousRoom: ("Previous room row", "K")
    case .addReturn: ("Add return path", "R")
    case .addSupply: ("Add supply path", "S")
    case .exportPDF: ("Export PDF", "E")
    case .heating: ("Heating airflow", "H")
    case .cooling: ("Cooling airflow", "C")
    case .pressure: ("Static pressure", "S")
    case .templateShared: ("Shared system template", "D")
    case .templateFurnace: ("Furnace template", "F")
    case .templateAirHandler: ("Air handler template", "A")
    case .nextGroup: ("Next group", "N")
    case .previousGroup: ("Previous group", "B")
    case .nextFitting: ("Next fitting", "J")
    case .previousFitting: ("Previous fitting", "K")
    case .fittingLeft: ("Fitting to the left", "H")
    case .fittingDown: ("Fitting below", "J")
    case .fittingUp: ("Fitting above", "K")
    case .fittingRight: ("Fitting to the right", "L")
    default: ("Group \(rawValue.dropFirst(5))", self == .group10 ? "0" : String(rawValue.suffix(1)))
    }
  }

  public var title: String { description.0 }
  public var defaultBinding: String {
    (self == .search ? "Control+" : "Control+Alt+") + description.1
  }

  public var section: String {
    switch self {
    case .reveal, .help, .search, .projects, .profile, .ductulator, .fittings: "App"
    case .project, .rooms, .equipment, .effectiveLength, .frictionRate, .ductSizes,
      .nextStep, .previousStep, .primaryAction:
      "Project navigation"
    case .nextRoom, .previousRoom, .importLoads: "Rooms"
    case .addReturn, .addSupply: "Total effective length"
    case .exportPDF: "Duct sizes"
    case .heating, .cooling, .pressure: "Equipment"
    case .templateShared, .templateFurnace, .templateAirHandler: "System templates"
    case .fittingLeft, .fittingDown, .fittingUp, .fittingRight: "Path templates"
    default: "Fitting reference"
    }
  }

  /// Contexts model where actions can run together, including app navigation on project pages.
  public var contexts: Set<String> {
    switch section {
    case "App":
      ["account", "project", "rooms", "equipment", "effectiveLength", "ductSizing", "fittings", "pathTemplates"]
    case "Project navigation": ["project", "rooms", "equipment", "effectiveLength", "ductSizing", "pathTemplates"]
    case "Rooms": ["rooms"]
    case "Total effective length": ["effectiveLength"]
    case "Duct sizes": ["ductSizing"]
    case "Equipment": ["equipment"]
    case "System templates": ["templates"]
    case "Path templates": ["pathTemplates"]
    default: ["fittings"]
    }
  }

  public var when: String {
    switch section {
    case "App": "Where the action is available"
    case "Project navigation": "In a project"
    case "System templates": "In the system template chooser"
    case "Path templates": "Choosing a fitting in a path template"
    default: "In \(section.lowercased())"
    }
  }
}

/// Stores only overrides so new actions and unchanged defaults remain available.
public struct Keybindings: Codable, Equatable, Sendable {
  public var overrides: [String: String]
  public init(overrides: [String: String] = [:]) { self.overrides = overrides }

  public subscript(_ action: KeybindingAction) -> String {
    overrides[action.rawValue] ?? action.defaultBinding
  }
  public var resolved: [String: String] {
    Dictionary(uniqueKeysWithValues: KeybindingAction.allCases.map { ($0.rawValue, self[$0]) })
  }
  public func label(_ action: KeybindingAction) -> String { Self.label(self[action]) }
  public static func label(_ binding: String) -> String {
    binding.split(separator: "+").map {
      switch $0 {
      case "Control": "Ctrl"
      case "Meta": "Command"
      default: String($0)
      }
    }.joined(separator: "+")
  }

  /// Apply only when loading persisted settings. Preserve older overrides that predate fitting navigation.
  public func resolvingLegacyFittingConflicts() throws -> Self {
    var result = self
    for action in [KeybindingAction.fittingLeft, .fittingDown, .fittingUp, .fittingRight]
    where overrides[action.rawValue] == nil {
      let occupied = Set(KeybindingAction.allCases.filter {
        $0 != action && !$0.contexts.isDisjoint(with: action.contexts)
      }.map { result[$0] })
      guard occupied.contains(result[action]) else { continue }
      let preferred = action.defaultBinding.replacingOccurrences(of: "Control+Alt+", with: "Control+Alt+Shift+")
      let candidates = [preferred] + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { "Control+Alt+Shift+\($0)" }
      guard let replacement = candidates.first(where: { !occupied.contains($0) }) else {
        throw KeybindingError("No available shortcut for \(action.title).")
      }
      result.overrides[action.rawValue] = replacement
    }
    return result
  }

  public func validated() throws -> Self {
    for (id, binding) in overrides {
      guard KeybindingAction(rawValue: id) != nil, Self.isValid(binding) else {
        throw KeybindingError("Choose a valid key combination for each action.")
      }
    }
    let actions = KeybindingAction.allCases
    for (index, action) in actions.enumerated() {
      for other in actions.dropFirst(index + 1)
      where !action.contexts.isDisjoint(with: other.contexts) {
        let a = self[action]
        let b = self[other]
        if a == b {
          throw KeybindingError(
            "\(action.title) and \(other.title) use \(Self.label(a)) in the same context.")
        }
      }
    }
    return .init(
      overrides: overrides.filter { $0.value != KeybindingAction(rawValue: $0.key)?.defaultBinding }
    )
  }

  public static func isValid(_ binding: String) -> Bool {
    let parts = binding.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
    guard parts.count >= 2, let key = parts.last else { return false }
    let modifiers = Array(parts.dropLast())
    let order = ["Control", "Alt", "Shift", "Meta"]
    guard modifiers == order.filter(modifiers.contains),
      modifiers.contains(where: { $0 != "Shift" })
    else { return false }
    let named = [
      "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Home", "End", "PageUp", "PageDown",
      "Insert", "Delete", "Backspace", "Enter", "Space",
    ]
    return (key.count == 1 && "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/[];='`\\,.-".contains(key))
      || named.contains(key) || (1...12).contains(where: { key == "F\($0)" })
  }
}

public struct KeybindingError: Error, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
}
