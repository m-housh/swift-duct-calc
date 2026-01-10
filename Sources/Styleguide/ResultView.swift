import Elementary
import Foundation

public struct ResultView<
  V: Sendable,
  E: Error,
  ValueView: HTML,
  ErrorView: HTML
>: HTML {

  let onSuccess: @Sendable (V) -> ValueView
  let onError: @Sendable (E) -> ErrorView
  let result: Result<V, E>

  public init(
    result: Result<V, E>,
    @HTMLBuilder onSuccess: @escaping @Sendable (V) -> ValueView,
    @HTMLBuilder onError: @escaping @Sendable (E) -> ErrorView
  ) {
    self.result = result
    self.onError = onError
    self.onSuccess = onSuccess
  }

  public var body: some HTML {
    switch result {
    case .success(let value):
      onSuccess(value)
    case .failure(let error):
      onError(error)
    }
  }
}

extension ResultView {

  public init(
    result: Result<V, E>,
    @HTMLBuilder onSuccess: @escaping @Sendable (V) -> ValueView
  ) where ErrorView == Styleguide.ErrorView<E> {
    self.init(result: result, onSuccess: onSuccess) { error in
      Styleguide.ErrorView(error: error)
    }
  }

  public init(
    catching: @escaping @Sendable () async throws(E) -> V,
    @HTMLBuilder onSuccess: @escaping @Sendable (V) -> ValueView
  ) async where ErrorView == Styleguide.ErrorView<E> {
    await self.init(
      result: .init(catching: catching),
      onSuccess: onSuccess
    ) { error in
      Styleguide.ErrorView(error: error)
    }
  }
}

extension ResultView: Sendable where Error: Sendable, ValueView: Sendable, ErrorView: Sendable {}

public struct ErrorView<E: Error>: HTML, Sendable where Error: Sendable {

  let error: E

  public init(error: E) {
    self.error = error
  }

  public var body: some HTML<HTMLTag.div> {
    div {
      h1(.class("text-2xl font-bold text-error")) { "Oops: Error" }
      p {
        "\(error)"
      }
    }
  }

}
