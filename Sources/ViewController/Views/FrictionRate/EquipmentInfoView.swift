import Elementary
import ManualDCore
import Styleguide

struct EquipmentInfoView: HTML, Sendable {
  let equipmentInfo: EquipmentInfo
  var projectID: Project.ID { equipmentInfo.projectID }

  var body: some HTML {
    div(.class("space-y-4 border border-gray-200 rounded-lg shadow-lg p-4")) {
      Row {
        h1(.class("text-2xl font-bold")) { "Equipment Info" }
      }

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

      Row {
        div {}
        EditButton()
          .attributes(
            .hx.get(route: .project(.detail(projectID, .frictionRate(.form(.equipmentInfo))))),
            .hx.target("#equipmentForm"),
            .hx.swap(.outerHTML)
          )
      }
    }

    div(.id("equipmentForm")) {}
  }
}
