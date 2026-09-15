import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct KeybindingsView: HTML, Sendable {
  let bindings: Keybindings
  var saved = false
  private var sections: [String] {
    KeybindingAction.allCases.reduce(into: []) {
      if !$0.contains($1.section) { $0.append($1.section) }
    }
  }
  var body: some HTML {
    AccountPage(selected: .keybindings) {
      header(.class("account-heading")) {
        h1 { "Keybindings" }
        p {
          "Select a shortcut and press a new combination. Use Ctrl, Alt, or Command with another key. Escape cancels recording."
        }
      }
      form(
        .id("keybindings-form"), .hx.post("/keybindings"), .hx.target("body"), .hx.swap(.outerHTML),
        .hx.disabledElt("find button"), .data("success-message", value: "Keybindings saved.")
      ) {
        input(.type(.hidden), .name("bindings"), .value(keybindingsJSON(bindings)))
        div(.class("keybindings-toolbar")) {
          label(.class("account-profile-field")) {
            span(.class("sr-only")) { "Find a keybinding" }
            input(
              .type(.search), .class("input"), .id("keybinding-search"),
              .placeholder("Find an action…"))
          }
          span(.class("keybindings-count")) { "\(KeybindingAction.allCases.count) bindings" }
          button(.type(.button), .class("btn btn-ghost"), .data("reset-keybindings", value: "")) {
            "Reset all"
          }
        }
        for sectionName in sections {
          section(.class("keybindings-section")) {
            h2 { sectionName }
            div(.class("keybindings-list")) {
              for action in KeybindingAction.allCases.filter({ $0.section == sectionName }) {
                div(
                  .class("keybinding-row"), .data("keybinding-action", value: action.rawValue),
                  .data("title", value: action.title),
                  .data("default", value: action.defaultBinding),
                  .data("contexts", value: action.contexts.sorted().joined(separator: " "))
                ) {
                  div(.class("keybinding-description")) {
                    h3 { action.title }
                    p { action.when }
                  }
                  div(.class("keybinding-controls")) {
                    button(
                      .type(.button), .class("keybinding-record"),
                      .data("binding", value: bindings[action]),
                      .init(
                        name: "aria-label",
                        value: "Change \(action.title) shortcut, \(bindings.label(action))"),
                      .init(name: "aria-describedby", value: "keybinding-status")
                    ) { Keycaps(bindings[action]) }
                    button(
                      .type(.button), .class("btn btn-ghost keybinding-reset"),
                      .data("reset-keybinding", value: ""),
                      .init(name: "aria-label", value: "Reset \(action.title) shortcut")
                    ) { "Reset" }
                    .attributes(.disabled, when: bindings[action] == action.defaultBinding)
                  }
                }
              }
            }
          }
        }
        p(.id("keybinding-empty"), .hidden) { "No matching actions." }
        div(.class("keybindings-footer")) {
          p(.id("keybinding-status"), .role("status"), .init(name: "aria-live", value: "polite")) {
            saved ? "Keybindings saved." : "Changes apply after saving."
          }
          button(.type(.submit), .class("btn btn-primary")) { "Save changes" }
        }
        noscript { p { "Enable JavaScript to record and save keybindings." } }
      }
    }
  }
}
