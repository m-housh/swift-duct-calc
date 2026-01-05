import Elementary
import ManualDCore
import Styleguide

struct FrictionRateView: HTML, Sendable {

  let equipmentInfo: EquipmentInfo?
  let componentLosses: [ComponentPressureLoss]
  let projectID: Project.ID

  var body: some HTML {
    div(.class("p-4 space-y-6")) {
      h1(.class("text-4xl font-bold pb-6")) { "Friction Rate" }
      EquipmentInfoView(equipmentInfo: equipmentInfo, projectID: projectID)
      ComponentPressureLossesView(
        componentPressureLosses: componentLosses, projectID: projectID
      )
    }
  }
}
