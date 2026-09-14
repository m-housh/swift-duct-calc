import Elementary
import ManualDCore
import Styleguide

struct TrunkTemplatesView: HTML, Sendable {
  let rooms: [DuctSizes.RoomContainer]

  private var levels: [Room.Level?] {
    [nil] + Set(rooms.compactMap(\.roomLevel)).sorted().map { Optional($0) }
  }

  var body: some HTML {
    div(.class("trunk-template-picker")) {
      div(.class("trunk-template-heading")) {
        span(.id("trunk-template-label")) { "Start from template" }
        small { "Optional" }
      }
      button(
        .type(.button), .class("trunk-template-trigger"),
        .data("trunk-template-toggle", value: ""),
        .init(name: "aria-labelledby", value: "trunk-template-label trunk-template-selection"),
        .init(name: "aria-expanded", value: "false"),
        .init(name: "aria-controls", value: "trunk-template-options")
      ) {
        span(.class("trunk-template-dot"), .init(name: "aria-hidden", value: "true")) {}
        span(.id("trunk-template-selection"), .data("trunk-template-summary", value: "")) {
          "No template"
        }
        SVG(.chevronDown)
      }
      div(
        .id("trunk-template-options"), .class("trunk-template-panel"), .hidden,
        .role("group"), .init(name: "aria-label", value: "Trunk templates")
      ) {
        button(
          .type(.button), .class("trunk-template-none"), .init(name: "value", value: ""),
          .data("trunk-template", value: ""), .data("runs", value: ""),
          .init(name: "aria-label", value: "No template"),
          .init(name: "aria-pressed", value: "true")
        ) {
          span {
            strong { "No template" }
            small { "Choose runs manually" }
          }
          span(.class("trunk-template-none-check"), .init(name: "aria-hidden", value: "true")) {
            "✓"
          }
        }
        table(.class("trunk-template-table"), .init(name: "aria-label", value: "Templates by scope and type")) {
          thead {
            tr {
              th(.init(name: "scope", value: "col")) { "Scope" }
              th(.init(name: "scope", value: "col")) { "Supply" }
              th(.init(name: "scope", value: "col")) { "Return" }
            }
          }
          tbody {
            for level in levels {
              TemplateRow(level: level, rooms: rooms.filter { level == nil || $0.roomLevel == level })
            }
          }
        }
      }
    }
  }

  private struct TemplateRow: HTML, Sendable {
    let level: Room.Level?
    let rooms: [DuctSizes.RoomContainer]

    private var runs: String {
      rooms.map { "\($0.roomID)_\($0.roomRegister)" }.joined(separator: ",")
    }

    private var countLabel: String {
      "\(level == nil ? "All " : "")\(rooms.count) \(rooms.count == 1 ? "run" : "runs")"
    }

    var body: some HTML<HTMLTag.tr> {
      tr {
        th(.init(name: "scope", value: "row")) {
          span { level?.label ?? "Main trunks" }
          small { countLabel }
        }
        for type in TrunkSize.TrunkType.allCases {
          let name = "\(level?.label ?? "Main") \(type.rawValue) trunk"
          td {
            button(
              .type(.button), .class("trunk-template-choice \(type.rawValue)"),
              .init(name: "value", value: name), .data("trunk-template", value: ""),
              .data("type", value: type.rawValue), .data("runs", value: runs),
              .init(name: "aria-label", value: name), .init(name: "aria-pressed", value: "false")
            ) {
              span(.class("trunk-template-radio"), .init(name: "aria-hidden", value: "true")) { "✓" }
            }
          }
        }
      }
    }
  }
}
