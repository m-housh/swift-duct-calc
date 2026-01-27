import Elementary
import Foundation

public struct ResultView<ValueView, ErrorView>: HTML where ValueView: HTML, ErrorView: HTML {

  let result: Result<ValueView, any Error>
  let errorView: @Sendable (any Error) -> ErrorView

  public init(
    _ content: @escaping @Sendable () async throws -> ValueView,
    onError: @escaping @Sendable (any Error) -> ErrorView
  ) async {
    self.result = await Result(catching: content)
    self.errorView = onError
  }

  public var body: some HTML {
    switch result {
    case .success(let view):
      view
    case .failure(let error):
      errorView(error)
    }
  }
}

extension ResultView where ErrorView == Styleguide.ErrorView {

  public init(
    _ content: @escaping @Sendable () async throws -> ValueView
  ) async {
    await self.init(
      content,
      onError: { Styleguide.ErrorView(error: $0) }
    )
  }

  public init<V: Sendable>(
    catching: @escaping @Sendable () async throws -> V,
    onSuccess content: @escaping @Sendable (V) -> ValueView
  ) async where ValueView: Sendable {
    await self.init(
      {
        try await content(catching())
      }
    )
  }

  public init(
    catching: @escaping @Sendable () async throws -> Void
  ) async where ValueView == EmptyHTML {
    await self.init(
      catching: catching,
      onSuccess: { EmptyHTML() }
    )
  }
}

extension ResultView: Sendable where ValueView: Sendable, ErrorView: Sendable {}

public struct ErrorView: HTML, Sendable {
  let error: any Error

  public init(error: any Error) {
    self.error = error
  }

  public var body: some HTML<HTMLTag.div> {
    div {
      h1(.class("text-xl font-bold text-error")) { "Oops: Error" }
      p {
        "\(error)"
      }
    }
  }
}
