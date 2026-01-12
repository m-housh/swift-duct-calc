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

public struct Input: HTML, Sendable {

  let id: String?
  let name: String?
  let placeholder: String

  private var _name: String {
    guard let name else {
      return id ?? ""
    }
    return name
  }

  init(
    id: String? = nil,
    name: String? = nil,
    placeholder: String
  ) {
    self.id = id
    self.name = name
    self.placeholder = placeholder
  }

  public init(
    id: String,
    name: String? = nil,
    placeholder: String
  ) {
    self.id = id
    self.name = name
    self.placeholder = placeholder
  }

  public init(
    name: String,
    placeholder: String
  ) {
    self.init(id: nil, name: name, placeholder: placeholder)
  }

  public var body: some HTML<HTMLTag.input> {
    input(
      .id(id ?? ""), .name(_name), .placeholder(placeholder),
      .class(
        """
        input w-full rounded-md bg-white px-3 py-1.5 text-slate-900 outline-1
        -outline-offset-1 outline-slate-300 focus:outline focus:-outline-offset-2
        focus:outline-indigo-600 invalid:border-red-500 out-of-range:border-red-500
        """
      )
    )
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
