import Elementary

public struct SVG: HTML, Sendable {

  let key: Key

  public init(_ key: Key) {
    self.key = key
  }

  public var body: some HTML {
    HTMLRaw(key.svg)
  }
}

extension SVG {
  public enum Key: Sendable {
    case close

    var svg: String {
      switch self {
      case .close:
        return """
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-x-icon lucide-x"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
          """
      }
    }
  }
}
