import Elementary

public struct LabeledInput: HTML, Sendable {

  let labelText: String
  let inputAttributes: [HTMLAttribute<HTMLTag.input>]

  public init(
    _ label: String,
    _ attributes: HTMLAttribute<HTMLTag.input>...
  ) {
    self.labelText = label
    self.inputAttributes = attributes
  }

  public var body: some HTML<HTMLTag.label> {
    label(.class("input w-full")) {
      span(.class("label")) { labelText }
      input(attributes: inputAttributes)
    }
  }
}

extension HTMLAttribute where Tag == HTMLTag.input {

  public static func max(_ value: String) -> Self {
    .init(name: "max", value: value)
  }

  public static func min(_ value: String) -> Self {
    .init(name: "min", value: value)
  }

  public static func step(_ value: String) -> Self {
    .init(name: "step", value: value)
  }

  public static func minlength(_ value: String) -> Self {
    .init(name: "minlength", value: value)
  }

  public static func pattern(value: String) -> Self {
    .init(name: "pattern", value: value)
  }

  public static func pattern(_ type: PatternType) -> Self {
    pattern(value: type.value)
  }
}

public enum PatternType: Sendable {
  case password
  case username

  var value: String {
    switch self {
    case .password:
      return "(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).{8,}"
    case .username:
      return "[A-Za-z][A-Za-z0-9\\-]*"
    }
  }
}
