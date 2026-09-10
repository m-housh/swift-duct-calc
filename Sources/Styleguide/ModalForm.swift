import Elementary

/// Editable content is a native dialog when dismissible, or a page form otherwise.
public struct ModalForm<T: HTML & Sendable>: HTML, Sendable {
  let dismiss: Bool
  let id: String
  let title: String
  let inner: T

  public init(id: String, title: String, dismiss: Bool, @HTMLBuilder inner: () -> T) {
    self.dismiss = dismiss
    self.id = id
    self.title = title
    self.inner = inner()
  }

  public var body: some HTML {
    if dismiss {
      dialog(.id(id), .class("modal"), .init(name: "aria-labelledby", value: "\(id)-title")) {
        div(.class("modal-box")) {
          h2(.id("\(id)-title"), .class("text-2xl font-bold mb-6 pe-10")) { title }
          button(
            .type(.button), .class("btn btn-sm btn-circle btn-ghost absolute right-2 top-2"),
            .init(name: "aria-label", value: "Close \(title)"),
            .on(.click, "this.closest('dialog').close()")
          ) { SVG(.close) }
          inner
        }
      }
    } else {
      section(.id(id), .class("page-form"), .init(name: "aria-labelledby", value: "\(id)-title")) {
        h1(.id("\(id)-title"), .class("text-2xl font-bold mb-6")) { title }
        inner
      }
    }
  }
}
