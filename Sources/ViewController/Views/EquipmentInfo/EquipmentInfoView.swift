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

        if equipmentInfo != nil {
          EditButton()
            .attributes(
              .hx.get(route: .project(.detail(projectID, .equipment(.form(dismiss: false))))),
              .hx.target("#equipmentForm"),
              .hx.swap(.outerHTML)
            )
        }
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

        EquipmentInfoForm(dismiss: true, projectID: projectID, equipmentInfo: nil)
      } else {
        EquipmentInfoForm(dismiss: false, projectID: projectID, equipmentInfo: nil)
      }
    }
  }
}
