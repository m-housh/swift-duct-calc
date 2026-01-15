import Elementary
import ManualDClient
import ManualDCore
import Styleguide

struct FrictionRateView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let componentLosses: [ComponentPressureLoss]
  let equivalentLengths: EffectiveLength.MaxContainer
  let frictionRateResponse: ManualDClient.FrictionRateResponse?

  private var availableStaticPressure: Double? {
    frictionRateResponse?.availableStaticPressure
  }

  private var frictionRateDesignValue: Double? {
    frictionRateResponse?.frictionRate
  }

  private var shouldShowBadges: Bool {
    frictionRateDesignValue != nil || availableStaticPressure != nil
  }

  private var badgeColor: String {
    let base = "badge-info"
    guard let frictionRateDesignValue else { return base }
    if frictionRateDesignValue >= 0.18 || frictionRateDesignValue <= 0.02 {
      return "badge-error"
    }
    return base
  }

  private var showHighErrors: Bool {
    guard let frictionRateDesignValue else { return false }
    return frictionRateDesignValue >= 0.18
  }

  private var showLowErrors: Bool {
    guard let frictionRateDesignValue else { return false }
    return frictionRateDesignValue <= 0.02
  }

  private var showNoComponentLossesError: Bool {
    componentLosses.count == 0
  }

  private var showIncompleteSectionsError: Bool {
    availableStaticPressure == nil || frictionRateDesignValue == nil
  }

  private var hasAlerts: Bool {
    showLowErrors
      || showHighErrors
      || showNoComponentLossesError
      || showIncompleteSectionsError

  }

  var body: some HTML {
    div(.class("space-y-6")) {
      PageTitleRow {
        div(.class("grid grid-cols-2 px-4 w-full")) {

          PageTitle { "Friction Rate" }

          div(.class("space-y-2 justify-end font-bold text-lg")) {
            if shouldShowBadges {

              if let frictionRateDesignValue {
                LabeledContent {
                  span { "Friction Rate Design Value" }
                } content: {
                  Badge(number: frictionRateDesignValue, digits: 2)
                    .attributes(.class("\(badgeColor) badge-lg"))
                    .bold()
                }
                .attributes(.class("justify-end mx-auto"))
              }

              if let availableStaticPressure {
                LabeledContent {
                  span { "Available Static Pressure" }
                } content: {
                  Badge(number: availableStaticPressure, digits: 2)
                }
                .attributes(.class("justify-end mx-auto"))
              }

              LabeledContent {
                span { "Component Pressure Losses" }
              } content: {
                Badge(number: componentLosses.total, digits: 2)
              }
              .attributes(.class("justify-end mx-auto"))
            }
          }

          div(.class("text-error font-bold italic col-span-2")) {
            Alert {
              p {
                "Must complete previous sections."
              }
            }
            .hidden(when: !showIncompleteSectionsError)

            Alert {
              p {
                "No component pressures losses"
              }
            }
            .hidden(when: !showNoComponentLossesError)

            Alert {
              p(.class("block")) {
                "Calculated friction rate is below 0.02. The fan may not deliver the required CFM."
                br()
                " * Increase the blower speed"
                br()
                " * Increase the blower size"
                br()
                " * Decrease the Total Effective Length (TEL)"
              }
            }
            .hidden(when: !showLowErrors)

            Alert {
              p(.class("block")) {
                "Calculated friction rate is above 0.18. The fan may deliver too many CFM."
                br()
                " * Decrease the blower speed"
                br()
                " * Decreae the blower size"
                br()
                " * Increase the Total Effective Length (TEL)"
              }
            }
            .hidden(when: !showHighErrors)

          }
          .attributes(.class("mt-4"), when: hasAlerts)
        }
      }

      ComponentPressureLossesView(
        componentPressureLosses: componentLosses, projectID: projectID
      )
    }
  }
}
