import Elementary
import ManualDCore

struct EquipmentTable: HTML, Sendable {
  let equipmentInfo: EquipmentInfo
  let projectSHR: Double

  var body: some HTML<HTMLTag.table> {
    table(.class("equipment-table")) {
      thead {
        tr {
          ReportColumn("Parameter")
          ReportColumn("Value")
        }
      }
      tbody {
        tr {
          td { "External static pressure" }
          td { "\(equipmentInfo.staticPressure.string()) in. w.c." }
        }
        tr {
          td { "Heating airflow" }
          td { "\(equipmentInfo.heatingCFM?.string() ?? "—") CFM" }
        }
        tr {
          td { "Cooling airflow" }
          td { "\(equipmentInfo.coolingCFM?.string() ?? "—") CFM" }
        }
        tr {
          td { "Sensible heat ratio" }
          td { projectSHR.string() }
        }
      }
    }
  }
}
