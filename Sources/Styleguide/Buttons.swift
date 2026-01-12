import Elementary

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

public struct CancelButton: HTML, Sendable {
  let title: String
  let type: HTMLAttribute<HTMLTag.button>.ButtonType

  public init(
    title: String = "Cancel",
    type: HTMLAttribute<HTMLTag.button>.ButtonType = .button
  ) {
    self.title = title
    self.type = type
  }

  public var body: some HTML<HTMLTag.button> {
    button(
      .class(
        """
        text-white font-bold text-xl bg-red-500 hover:bg-red-600 px-4 py-2 rounded-lg shadow-lg
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
    button(.class("btn hover:btn-success"), .type(type)) {
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
      .class("btn btn-primary btn-circle text-xl")
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
