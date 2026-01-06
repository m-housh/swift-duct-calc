import Elementary
import ManualDCore
import Styleguide

struct EquipmentInfoView: HTML, Sendable {
  let equipmentInfo: EquipmentInfo?
  var projectID: Project.ID

  var body: some HTML {
    div(
      .class("space-y-4 border border-gray-200 rounded-lg shadow-lg p-4"),
      .id("equipmentInfo")
    ) {

      Row {
        h1(.class("text-2xl font-bold")) { "Equipment Info" }

        EditButton()
          .attributes(
            .on(.click, "\(EquipmentInfoForm.id).showModal()")
          )
      }

      if let equipmentInfo {

        Row {
          Label { "Static Pressure" }
          Number(equipmentInfo.staticPressure)
        }
        .attributes(.class("border-b border-gray-200"))

        Row {
          Label { "Heating CFM" }
          Number(equipmentInfo.heatingCFM)
        }
        .attributes(.class("border-b border-gray-200"))

        Row {
          Label { "Cooling CFM" }
          Number(equipmentInfo.coolingCFM)
        }
        .attributes(.class("border-b border-gray-200"))

      }
      EquipmentInfoForm(
        dismiss: true, projectID: projectID, equipmentInfo: equipmentInfo
      )
    }
  }
}
