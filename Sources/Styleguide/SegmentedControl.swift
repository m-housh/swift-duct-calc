import Elementary

/// A single-choice control with native radio-button keyboard navigation.
public struct SegmentedControl: HTML, Sendable {
  public struct Option: Sendable {
    let value: String
    let label: String
    public init(value: String, label: String) {
      self.value = value
      self.label = label
    }
  }

  let name: String
  let title: String
  let options: [Option]
  let selected: String

  public init(name: String, title: String, options: [Option], selected: String) {
    self.name = name
    self.title = title
    self.options = options
    self.selected = selected
  }

  public var body: some HTML {
    fieldset(.class("picker-segments")) {
      legend { title }
      div(.class("picker-segment-options")) {
        for option in options {
          label {
            input(.type(.radio), .name(name), .value(option.value)).attributes(
              .checked, when: option.value == selected)
            span { option.label }
          }
        }
      }
    }
  }
}
