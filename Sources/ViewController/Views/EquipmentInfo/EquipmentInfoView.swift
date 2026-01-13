import Elementary
import ManualDCore
import Styleguide

struct EquipmentInfoView: HTML, Sendable {
  let equipmentInfo: EquipmentInfo?
  var projectID: Project.ID

  var body: some HTML {
    div(
      .class("space-y-4"),
      .id("equipmentInfo")
    ) {

      Row {
        PageTitle { "Equipment Info" }

        Tooltip("Edit equipment info") {
          EditButton()
            .attributes(
              .class("btn-ghost"),
              .showModal(id: EquipmentInfoForm.id)
            )
        }
      }

      if let equipmentInfo {

        table(.class("table table-zebra")) {
          tbody(.class("text-lg")) {
            tr {
              td { Label { "Static Pressure" } }
              td {
                div(.class("flex justify-end")) {
                  Number(equipmentInfo.staticPressure)
                }
              }
            }
            tr {
              td { Label { "Heating CFM" } }
              td {
                div(.class("flex justify-end")) {
                  Number(equipmentInfo.heatingCFM)
                }
              }
            }
            tr {
              td { Label { "Cooling CFM" } }
              td {
                div(.class("flex justify-end")) {
                  Number(equipmentInfo.coolingCFM)
                }
              }
            }
          }
        }
      }
      EquipmentInfoForm(
        dismiss: true, projectID: projectID, equipmentInfo: equipmentInfo
      )
    }
  }
}
