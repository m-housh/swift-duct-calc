import Elementary

/// Native checkboxes submit repeated fields and support keyboard and touch without custom roles.
public struct CheckboxGroup: HTML, Sendable {
  public struct Option: Sendable {
    let value: String
    let label: String
    let selected: Bool

    public init(value: String, label: String, selected: Bool = false) {
      self.value = value
      self.label = label
      self.selected = selected
    }
  }

  let title: String
  let name: String
  let options: [Option]

  public init(_ title: String, name: String, options: [Option]) {
    self.title = title
    self.name = name
    self.options = options
  }

  public var body: some HTML {
    fieldset(.class("checkbox-group")) {
      legend(.class("font-bold")) { title }
      if options.isEmpty {
        p { "No supply runs available." }
      } else {
        div(.class("flex flex-wrap gap-2 my-2")) {
          button(.type(.button), .class("btn btn-sm"), .data("check-all", value: "true")) { "Select all" }
          button(.type(.button), .class("btn btn-sm"), .data("check-all", value: "false")) { "Clear selection" }
        }
        div(.class("checkbox-options")) {
          for option in options {
            label {
              input(.type(.checkbox), .class("checkbox"), .name(name), .value(option.value))
                .attributes(.checked, when: option.selected)
              span { option.label }
            }
          }
        }
      }
    }
  }
}
