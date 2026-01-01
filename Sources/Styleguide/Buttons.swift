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
        text-white font-bold text-xl bg-blue-500 hover:bg-blue-600 px-4 py-2 rounded-lg shadow-lg
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
  let title: String
  let type: HTMLAttribute<HTMLTag.button>.ButtonType

  public init(
    title: String = "Edit",
    type: HTMLAttribute<HTMLTag.button>.ButtonType = .button
  ) {
    self.title = title
    self.type = type
  }

  public var body: some HTML<HTMLTag.button> {
    button(
      .class(
        """
        text-white font-bold text-xl bg-blue-500 hover:bg-blue-600 px-4 py-2 rounded-lg shadow-lg
        """
      ),
      .type(type)
    ) {
      div(.class("flex")) {
        span(.class("pe-2")) { title }
        SVG(.squarePen)
      }
    }
  }
}
