import Elementary

public struct Input: HTML, Sendable {
  let id: String
  let name: String?
  let placeholder: String

  public init(
    id: String,
    name: String? = nil,
    placeholder: String
  ) {
    self.id = id
    self.name = name
    self.placeholder = placeholder
  }

  public var body: some HTML<HTMLTag.input> {
    input(
      .id(id), .name(name ?? id), .placeholder(placeholder),
      .class(
        """
        w-full rounded-md bg-white px-3 py-1.5 text-slate-900 outline-1
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
}
