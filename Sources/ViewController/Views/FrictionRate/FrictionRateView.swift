import Elementary
import ManualDClient
import ManualDCore
import Styleguide

// FIX: Need to update available static, etc. when equipment info is submitted.

struct FrictionRateView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let componentLosses: [ComponentPressureLoss]
  let equivalentLengths: EffectiveLength.MaxContainer
  let frictionRateResponse: ManualDClient.FrictionRateResponse?

  var availableStaticPressure: Double? {
    frictionRateResponse?.availableStaticPressure
  }

  var frictionRateDesignValue: Double? {
    frictionRateResponse?.frictionRate
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
    div(.class("space-y-6")) {
      div(.class("grid grid-cols-2 px-4")) {

        PageTitle { "Friction Rate" }

        div(.class("space-y-4 justify-end")) {

          if let frictionRateDesignValue {
            LabeledContent("Friction Rate Design Value") {
              Badge(number: frictionRateDesignValue, digits: 2)
                .attributes(.class("\(badgeColor)"))
            }
            .attributes(.class("justify-end"))
          }

          if let availableStaticPressure {
            LabeledContent("Available Static Pressure") {
              Badge(number: availableStaticPressure, digits: 2)
            }
            .attributes(.class("justify-end"))
          }
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

      div(.class("divider")) {}

      ComponentPressureLossesView(
        componentPressureLosses: componentLosses, projectID: projectID
      )
    }
  }
}
