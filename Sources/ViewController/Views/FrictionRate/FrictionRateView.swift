import Elementary
import ManualDCore
import Styleguide

struct FrictionRateView: HTML, Sendable {

  var body: some HTML {
    div(.class("w-full flex-1 p-4 space-y-6")) {
      h1(.class("text-4xl font-bold pb-6")) { "Friction Rate" }
      EquipmentInfoView(equipmentInfo: EquipmentInfo.mock)
      ComponentPressureLossTable(componentPressureLosses: ComponentPressureLoss.mock)
    }
  }
}
