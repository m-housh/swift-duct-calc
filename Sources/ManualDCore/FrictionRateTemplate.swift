/// Built-in starting points for a project's component pressure losses.
public enum FrictionRateTemplate: String, CaseIterable, Codable, Sendable {
  case shared = "shared"
  case furnace = "furnace"
  case airHandler = "air-handler"

  public var name: String {
    switch self {
    case .shared: "Shared defaults"
    case .furnace: "Furnace + evaporator coil"
    case .airHandler: "Air handler"
    }
  }

  public func components(projectID: Project.ID) -> [ComponentPressureLoss.Create] {
    var components = ComponentPressureLoss.Create.default(projectID: projectID)
    if self == .furnace {
      components.append(.init(projectID: projectID, name: "evaporator-coil", value: 0.2))
    }
    if self != .shared {
      components.append(.init(projectID: projectID, name: "filter", value: 0.1))
    }
    return components
  }
}
