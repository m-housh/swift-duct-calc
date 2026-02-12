import Elementary
import ElementaryHTMX
import ManualDCore

public struct SubmitButton: HTML, Sendable {
  let title: String
  let type: HTMLAttribute<HTMLTag.button>.ButtonType

  public init(
    title: String = "Submit",
    type: HTMLAttribute<HTMLTag.button>.ButtonType = .submit
  ) {
    self.title = title
    self.type = type
  }

  public var body: some HTML<HTMLTag.button> {
    button(
      .class(
        """
        btn btn-secondary
        """
      ),
      .type(type)
    ) {
      title
    }
  }
}

public struct EditButton: HTML, Sendable {
  let title: String?
  let type: HTMLAttribute<HTMLTag.button>.ButtonType

  public init(
    title: String? = nil,
    type: HTMLAttribute<HTMLTag.button>.ButtonType = .button
  ) {
    self.title = title
    self.type = type
  }

  public var body: some HTML<HTMLTag.button> {
    button(.class("btn"), .type(type)) {
      div(.class("flex")) {
        if let title {
          span(.class("pe-2")) { title }
        }
        SVG(.squarePen)
      }
    }
  }
}

public struct PlusButton: HTML, Sendable {

  public init() {}

  public var body: some HTML<HTMLTag.button> {
    button(
      .type(.button),
      .class("btn")
    ) { SVG(.circlePlus) }
  }
}

public struct TrashButton: HTML, Sendable {
  public init() {}

  public var body: some HTML<HTMLTag.button> {
    button(
      .type(.button),
      .class("btn btn-error")
    ) {
      SVG(.trash)
    }
  }
}

public struct DuctulatorButton: HTML, Sendable {
  public init() {}

  public var body: some HTML<HTMLTag.a> {
    a(
      .class("btn"),
      .href(route: .ductulator(.index)),
      .target(.blank)
    ) {
      "Ductulator"
    }
  }
}
