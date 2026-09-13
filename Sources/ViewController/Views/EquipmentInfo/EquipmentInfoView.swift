import Elementary
import Foundation
import ManualDCore
import Styleguide

struct EquipmentInfoView: HTML, Sendable {
  let equipmentInfo: EquipmentInfo?
  var projectID: Project.ID
  var readOnly = false

  var body: some HTML {
    div(.class("equipment-visual")) {
      PageTitleRow {
        div {
          PageTitle { "Equipment" }
          p(.class("muted")) { "Select heating, cooling, or the air handler to edit its value." }
        }
        button(
          .type(.button), .class("btn btn-primary"),
          .showModal(id: EquipmentInfoForm.Field.all.id),
          .init(name: "aria-keyshortcuts", value: "Control+Alt+E"),
          .title("Edit equipment, Ctrl+Alt+E")
        ) {
          SVG(.squarePen)
          "Edit equipment"
        }
      }
      details(
        .class("project-panel equipment-canvas"), .init(name: "open", value: ""),
        .data("expansion", value: "equipment-airflow")
      ) {
        summary(.class("canvas-legend")) {
          span(.class("network-toggle")) {
            SVG(.chevronRight)
            "SYSTEM AIRFLOW"
          }
          span(.class("equipment-summary-note")) { "Main system · Heating & cooling" }
        }
        div(.class("equipment-network")) {
          if readOnly {
            previewDucts
          } else {
            HTMLRaw("<svg class=\"airflow-lines\" aria-hidden=\"true\"></svg>")
          }
          airflowCard(.heating, value: equipmentInfo?.heatingCFM)
          blower
          airflowCard(.cooling, value: equipmentInfo?.coolingCFM)
        }
      }
      if !readOnly {
        for field in EquipmentInfoForm.Field.allCases {
          EquipmentInfoForm(equipmentInfo: equipmentInfo, field: field)
        }
      }
    }
    if !readOnly { script(.src("/js/equipment.js?v=1"), .defer) {} }
  }

  private func airflowCard(_ field: EquipmentInfoForm.Field, value: Int?) -> some HTML & Sendable {
    let mode = field.rawValue
    let label = field == .heating ? "Heating" : "Cooling"
    return button(
      .type(.button), .class("mode-card \(mode)\(value == nil ? " is-empty" : "")"),
      .data("equipment-mode", value: mode), .showModal(id: field.id),
      .init(name: "aria-keyshortcuts", value: "Control+Alt+\(field.key)"),
      .init(
        name: "aria-label", value: value.map { "Edit \(mode) airflow, \($0) CFM" } ?? "Add \(mode)"),
      .title("\(field.title), Ctrl+Alt+\(field.key)")
    ) {
      span(.class("mode-label")) {
        modeIcon(heating: field == .heating)
        label
      }
      if let value {
        strong(.class("airflow-value")) {
          Number(value)
          small { " CFM" }
        }
        span(.class("edit-hint")) {
          SVG(.squarePen)
          "Edit airflow"
        }
      } else {
        span(.class("edit-hint")) {
          SVG(.circlePlus)
          "Add \(mode)"
        }
      }
      span(.class("port"), .init(name: "aria-hidden", value: "true")) {}
    }
  }

  private var blower: some HTML & Sendable {
    button(
      .type(.button), .class("blower"), .showModal(id: EquipmentInfoForm.Field.pressure.id),
      .init(name: "aria-keyshortcuts", value: "Control+Alt+S"),
      .init(
        name: "aria-label",
        value: "Edit external static pressure, \(pressure) inches of water column"),
      .title("External static pressure, Ctrl+Alt+S")
    ) {
      housing
      span(.class("pressure-readout")) {
        strong(.class("pressure-value")) { pressure }
        span(.class("pressure-unit")) { "in. w.c." }
        span(.class("pressure-label")) { "External static pressure" }
      }
      span(.class("blower-label")) {
        span { "Air handler" }
        span(.class("edit-hint")) {
          SVG(.squarePen)
          "Edit"
        }
      }
    }
  }

  private var pressure: String { String(format: "%.2f", equipmentInfo?.staticPressure ?? 0.5) }

  // The landing-page sample is sandboxed without scripts at a fixed desktop size.
  private var previewDucts: some HTML & Sendable {
    HTMLRaw(
      """
      <svg class="airflow-lines" viewBox="0 0 1000 540" preserveAspectRatio="none" aria-hidden="true">
        <path class="duct-edge" stroke-width="44" d="M424 87H180Q160 87 160 107V143 M576 87H820Q840 87 840 107V143"/>
        <path class="duct-face" stroke-width="42" d="M424 87H180Q160 87 160 107V143 M576 87H820Q840 87 840 107V143"/>
        <path class="plenum" d="M466 90L424 66V108L466 150Z M534 90L576 66V108L534 150Z"/>
        <path class="plenum" d="M464 62H536V216L546 258H454L464 216Z"/>
        <path class="duct-seam" d="M464 68H536 M464 216H536"/>
      </svg>
      """)
  }

  private var housing: some HTML & Sendable {
    HTMLRaw(
      """
      <svg class="blower-housing" viewBox="0 0 200 280" aria-hidden="true">
          <path class="housing-shadow" d="M24 36 L36 28 H188 V246 L176 254 H24 Z"/>
          <path class="outlet" d="M50 36 V10 H150 V36"/>
          <rect class="housing-body" x="24" y="36" width="152" height="218" rx="4"/>
          <path class="cabinet-detail" d="M25 178 H175 M38 51 H45 M155 51 H162 M38 164 H45 M155 164 H162 M48 200 H64 M48 209 H64 M48 218 H64 M136 200 H152 M136 209 H152 M136 218 H152"/>
          <circle class="cabinet-detail" cx="100" cy="211" r="24"/>
          <g class="cabinet-fan" transform="translate(88 199)"><path d="M10.827 16.379a6.082 6.082 0 0 1-8.618-7.002l5.412 1.45a6.082 6.082 0 0 1 7.002-8.618l-1.45 5.412a6.082 6.082 0 0 1 8.618 7.002l-5.412-1.45a6.082 6.082 0 0 1-7.002 8.618l1.45-5.412Z"/></g>
          <path class="cabinet-detail" d="M36 255 V261 H59 V255 M141 255 V261 H164 V255"/>
        </svg>
      """)
  }

  private func modeIcon(heating: Bool) -> some HTML & Sendable {
    HTMLRaw(
      heating
        ? """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/></svg>
        """
        : """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2v20M3.34 7l17.32 10M3.34 17L20.66 7M9 4l3 3 3-3M9 20l3-3 3 3M3.5 10l4.1-1.1L6.5 4.8M17.5 19.2l-1.1-4.1 4.1-1.1M3.5 14l4.1 1.1-1.1 4.1M17.5 4.8l-1.1 4.1 4.1 1.1"/></svg>
        """)
  }
}
