import Elementary

public struct PickerField: Sendable {
  public let name: String
  public let label: String
  public var choices: [(String, String)]? = nil
  public var kind = "number"
  public var help = ""
  public init(
    name: String, label: String, choices: [(String, String)]? = nil, kind: String = "number",
    help: String = ""
  ) {
    self.name = name
    self.label = label
    self.choices = choices
    self.kind = kind
    self.help = help
  }
}

public struct PickerControl: HTML, Sendable {
  let field: PickerField
  let values: [String: String]
  var prefix = ""
  public init(field: PickerField, values: [String: String], prefix: String = "") {
    self.field = field
    self.values = values
    self.prefix = prefix
  }
  var name: String { prefix + field.name }
  public var body: some HTML {
    if field.kind == "hidden" {
      input(.type(.hidden), .name(name), .value("90"))
    } else {
      label(
        .class(field.kind == "checkbox" ? "fp-checkbox" : "fp-field"), .data("field", value: name)
      ) {
        if field.kind == "checkbox" {
          input(.type(.checkbox), .name(name), .value("true")).attributes(
            .checked, when: values[name] == "true")
          span { field.label }
        } else {
          span { field.label }
          if let choices = field.choices {
            select(.name(name)) {
              option(.value("")) { "Choose…" }.attributes(
                .selected, when: values[name, default: ""].isEmpty)
              for (value, label) in choices {
                option(.value(value)) { label }.attributes(.selected, when: values[name] == value)
              }
            }
          } else {
            input(
              .type(.number), .name(name), .value(values[name, default: ""]), .min("0"),
              .step(field.kind == "integer" ? "1" : "any"))
          }
        }
        if !field.help.isEmpty { small { field.help } }
      }
    }
  }
}
