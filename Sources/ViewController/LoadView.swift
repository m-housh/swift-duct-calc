import Elementary

/// Load data before constructing HTML, allowing failures to reach the request error handler.
func loadView<Value, Content: HTML & Sendable>(
  _ load: () async throws -> Value,
  onSuccess: (Value) async throws -> Content
) async rethrows -> some HTML & Sendable {
  try await onSuccess(load())
}

func loadView<Content: HTML & Sendable>(
  _ content: () async throws -> Content
) async rethrows -> some HTML & Sendable {
  try await content()
}
