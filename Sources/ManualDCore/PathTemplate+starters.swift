import Dependencies
import Foundation

extension PathTemplate {
  public static func starterConfigurations() -> [Configuration] {
    @Dependency(\.uuid) var uuid
    func step(
      _ title: String, _ group: TemplateFitting.Group, _ ids: [TemplateFitting.ID],
      behavior: Behavior = .chooseOne, optional: Bool = false
    ) -> Step {
      .init(
        id: uuid(), title: title, group: group, behavior: behavior,
        allowsSkipping: optional, choices: ids.map { .init(fittingID: $0) }
      )
    }
    func elbows() -> Step {
      .init(
        id: uuid(), title: "Elbows", group: .elbow, behavior: .quantities,
        allowsSkipping: true,
        choices: [
          .init(fittingID: "8A-4-or-5-piece", defaults: .sourceTable(choices: ["1"])),
          .init(fittingID: "8A-3-piece-45"),
        ]
      )
    }
    func transitions() -> Step {
      step(
        "Transitions", .transition, ["12J", "12S", "12T", "12U"],
        behavior: .chooseMultiple, optional: true
      )
    }
    return [
      .init(
        name: "My usual supply path", type: .supply,
        steps: [
          step("Equipment connection", .supplyConnection, ["1A", "1B", "1C", "1D", "1E"]),
          step(
            "Supply trunk branch takeoff", .supplyTakeoff,
            ["2N", "2O", "2P", "2Q", "2A", "2B"], optional: true
          ),
          step("Boot", .supplyBoot, ["4G", "4Q", "4R"]),
          elbows(), transitions(),
        ]),
      .init(
        name: "My usual return path", type: .return,
        steps: [
          step(
            "Equipment connection", .returnConnection,
            [
              "5A-round", "5C-round", "5E-round", "5E-rectangular", "5F-rectangular",
              "5H-rectangular", "5I-rectangular", "5J-rectangular",
            ]),
          step(
            "Return branch / boot", .returnTakeoff,
            [
              "6I", "6J", "6K", "6L", "6M", "6N", "6F", "6H",
            ]),
          elbows(), transitions(),
        ]),
    ]
  }
}
