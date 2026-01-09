import Elementary
import ManualDCore
import Styleguide

struct FrictionRateView: HTML, Sendable {

  let equipmentInfo: EquipmentInfo?
  let componentLosses: [ComponentPressureLoss]
  let equivalentLengths: EffectiveLength.MaxContainer
  let projectID: Project.ID

  var availableStaticPressure: Double? {
    guard let staticPressure = equipmentInfo?.staticPressure else {
      return nil
    }
    return staticPressure - componentLosses.totalComponentPressureLoss
  }

  var frictionRateDesignValue: Double? {
    guard let availableStaticPressure, let tel = equivalentLengths.total else {
      return nil
    }
    return (((availableStaticPressure * 100) / tel) * 100) / 100
  }

  var badgeColor: String {
    let base = "badge-primary"
    guard let frictionRateDesignValue else { return base }
    if frictionRateDesignValue >= 0.18 || frictionRateDesignValue <= 0.02 {
      return "badge-error"
    }
    return base
  }

  var showHighErrors: Bool {
    guard let frictionRateDesignValue else { return false }
    return frictionRateDesignValue >= 0.18
  }

  var showLowErrors: Bool {
    guard let frictionRateDesignValue else { return false }
    return frictionRateDesignValue <= 0.02
  }

  var body: some HTML {
    div(.class("p-4 space-y-6")) {
      h1(.class("text-4xl font-bold pb-6")) { "Friction Rate" }
      div(.class("flex space-x-4")) {
        Label("Available Static Pressure")
        if let availableStaticPressure {
          Number(availableStaticPressure, digits: 2)
            .attributes(.class("badge badge-lg badge-outline font-bold ms-4"))
        }
      }
      div(.class("flex space-x-4")) {
        if let frictionRateDesignValue {
          Label("Friction Rate Design Value")
          Number(frictionRateDesignValue, digits: 2)
            .attributes(.class("badge badge-lg badge-outline \(badgeColor) font-bold"))
        }
      }

      div(.class("text-error italic")) {
        p {
          "No component pressures losses"
        }
        .attributes(.class("hidden"), when: componentLosses.totalComponentPressureLoss > 0)

        p {
          "Calculated friction rate is below 0.02. The fan may not deliver the required CFM."
          br()
          " * Increase the blower speed"
          br()
          " * Increase the blower size"
          br()
          " * Decrease the Total Effective Length (TEL)"
        }
        .attributes(.class("hidden"), when: !showLowErrors)

        p {
          "Calculated friction rate is above 0.18. The fan may deliver too many CFM."
          br()
          " * Decrease the blower speed"
          br()
          " * Decreae the blower size"
          br()
          " * Increase the Total Effective Length (TEL)"
        }
        .attributes(.class("hidden"), when: !showHighErrors)
      }

      div(.class("grid grid-cols-1 lg:grid-cols-2 gap-4")) {
        EquipmentInfoView(equipmentInfo: equipmentInfo, projectID: projectID)
        ComponentPressureLossesView(
          componentPressureLosses: componentLosses, projectID: projectID
        )
      }
    }
  }
}
