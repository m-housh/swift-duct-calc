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

      PageTitleRow {
        PageTitle { "Equipment Details" }

        EditButton(accessibilityLabel: "Edit equipment")
          .attributes(
            .class("btn-primary"),
            .showModal(id: EquipmentInfoForm.id)
          )
          .tooltip("Edit equipment details")
      }

      if let equipmentInfo {

        table(.class("table details-table table-zebra")) {
          tbody(.class("text-lg")) {
            tr {
              th(.init(name: "scope", value: "row")) { Label { "Static Pressure" } }
              td {
                div(.class("flex justify-end")) {
                  Number(equipmentInfo.staticPressure)
                }
              }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label { "Heating CFM" } }
              td {
                div(.class("flex justify-end")) {
                  Number(equipmentInfo.heatingCFM)
                }
              }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label { "Cooling CFM" } }
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
        dismiss: true,
        equipmentInfo: equipmentInfo
      )
    }
  }
}
