import Elementary
import Foundation
import ManualDCore
import Styleguide

struct EquipmentInfoView: HTML, Sendable {
  let equipmentInfo: EquipmentInfo?
  var projectID: Project.ID
  var body: some HTML {
    div {
      PageTitleRow {
        div {
          PageTitle { "Equipment" }
          p(.class("muted")) { "Set the airflow and external static pressure for this system." }
        }
      }
      section(.class("project-panel equipment-panel")) {
        div(.class("equipment-heading")) {
          SVG(.fan)
          div {
            h2 { "Main system" }
            p(.class("muted")) { "Heating & cooling airflow" }
          }
        }
        div(.class("design-metrics equipment-metrics")) {
          DesignMetric(
            "Heating airflow", value: equipmentInfo.map { "\($0.heatingCFM)" } ?? "Not set",
            unit: "CFM")
          DesignMetric(
            "Cooling airflow", value: equipmentInfo.map { "\($0.coolingCFM)" } ?? "Not set",
            unit: "CFM")
          DesignMetric(
            "External static pressure",
            value: equipmentInfo.map { String(format: "%.2f", $0.staticPressure) } ?? "Not set",
            unit: "in. w.c.")
        }
        div(.class("equipment-editor")) {
          EquipmentInfoForm(dismiss: false, equipmentInfo: equipmentInfo, inline: true)
          p(.class("muted")) {
            "Use the blower's rated airflow at the selected external static pressure."
          }
        }
      }
    }
  }
}
