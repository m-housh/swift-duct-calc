import Elementary

public struct ModalForm<T: HTML>: HTML, Sendable where T: Sendable {

  let dismiss: Bool
  let id: String
  let inner: T

  public init(
    id: String,
    dismiss: Bool,
    @HTMLBuilder inner: () -> T
  ) {
    self.dismiss = dismiss
    self.id = id
    self.inner = inner()
  }

  public var body: some HTML {
    if dismiss {
      div(.id(id)) {}
    } else {
      div(
        .id(id),
        .class(
          """
          fixed top-40 left-[25vw] w-1/2 z-50 text-gray-800
          bg-gray-200 border border-gray-400 
          rounded-lg shadow-lg mx-10
          """
        )
      ) {
        inner
      }
    }
  }
}
