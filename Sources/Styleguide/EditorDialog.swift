import Elementary

/// Large form dialog. The owning controller handles opening and unsaved-change dismissal.
public struct EditorDialog<Inner: HTML & Sendable>: HTML, Sendable {
  let id: String
  let titleID: String
  let inner: Inner

  public init(id: String, titleID: String, @HTMLBuilder content: () -> Inner) {
    self.id = id
    self.titleID = titleID
    self.inner = content()
  }

  public var body: some HTML<HTMLTag.dialog> {
    dialog(.id(id), .class("editor-dialog"), .init(name: "aria-labelledby", value: titleID)) {
      inner
    }
  }
}
