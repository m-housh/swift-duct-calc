/// The sample project follows the order of the app's design sections.
public enum HomePreviewStep: String, CaseIterable, Equatable, Sendable {
  case rooms
  case equipment
  case paths
  case pressure
  case sizes

  public var title: String {
    switch self {
    case .rooms: "Room loads"
    case .equipment: "Equipment"
    case .paths: "Duct paths"
    case .pressure: "Friction rate"
    case .sizes: "Duct sizes"
    }
  }
}
