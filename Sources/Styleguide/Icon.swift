import Elementary

// TODO: Remove, using svg's.
public struct Icon: HTML, Sendable {

  let icon: String

  public init(icon: String) {
    self.icon = icon
  }

  public var body: some HTML {
    i(.data("lucide", value: icon)) {}
  }
}

extension Icon {

  public init(_ icon: Key) {
    self.init(icon: icon.icon)
  }

  public enum Key: String {

    case circlePlus
    case close
    case doorClosed
    case mapPin
    case rulerDimensionLine
    case squareFunction
    case wind

    var icon: String {
      switch self {
      case .circlePlus: return "circle-plus"
      case .close: return "x"
      case .doorClosed: return "door-closed"
      case .mapPin: return "map-pin"
      case .rulerDimensionLine: return "ruler-dimension-line"
      case .squareFunction: return "square-function"
      case .wind: return rawValue
      }
    }
  }
}
