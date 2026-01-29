import Elementary
import ManualDCore

struct EquipmentTable: HTML, Sendable {
  let title: String?
  let equipmentInfo: EquipmentInfo

  init(title: String? = nil, equipmentInfo: EquipmentInfo) {
    self.title = title
    self.equipmentInfo = equipmentInfo
  }

  var body: some HTML<HTMLTag.table> {

    table {
      thead {
        tr(.class("bg-green")) {
          th { title ?? "" }
          th(.class("justify-end")) { "Value" }
        }
      }
      tbody {
        tr {
          td { "Static Pressure" }
          td(.class("justify-end")) { equipmentInfo.staticPressure.string() }
        }
        tr {
          td { "Heating CFM" }
          td(.class("justify-end")) { equipmentInfo.heatingCFM.string() }
        }
        tr {
          td { "Cooling CFM" }
          td(.class("justify-end")) { equipmentInfo.coolingCFM.string() }
        }
      }
    }
  }
}
