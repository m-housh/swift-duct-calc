import Elementary

public struct ModalForm<T: HTML>: HTML, Sendable where T: Sendable {

  let closeButton: Bool
  let dismiss: Bool
  let id: String
  let inner: T

  public init(
    id: String,
    closeButton: Bool = true,
    dismiss: Bool,
    @HTMLBuilder inner: () -> T
  ) {
    self.closeButton = closeButton
    self.dismiss = dismiss
    self.id = id
    self.inner = inner()
  }

  public var body: some HTML {
    dialog(.id(id), .class("modal")) {
      div(.class("modal-box")) {
        if closeButton {
          button(
            .class("btn btn-sm btn-circle btn-ghost absolute right-2 top-2"),
            .on(.click, "\(id).close()")
          ) {
            SVG(.close)
          }
        }
        inner
      }
    }
    .attributes(.class("modal-open"), when: dismiss == false)
  }
}
