import Elementary
import Foundation
import ManualDCore
import Styleguide

struct PickerConfiguration: HTML, Sendable {
  let submission: SiteRoute.View.FittingPickerRoute.Submission
  let definition: Fitting.Definition
  let definitions: [Fitting.Definition]
  let artworks: [Fitting.Artwork]

  var values: [String: String] {
    PickerFields.defaults(definition.defaultInputs).merging(submission.fields) { _, new in new }
  }
  var baseDefinition: Fitting.Definition? {
    guard case .doubleElbow(let ids) = definition.inputRequirement,
      let id = values["baseFitting"], ids.contains(where: { $0.rawValue == id })
    else { return nil }
    return definitions.first { $0.id.rawValue == id }
  }
  var body: some HTML {
    div(.class("fitting-configuration")) { layout }
  }
  @HTMLBuilder var layout: some HTML {
    p(.class("fp-eyebrow")) { definition.sourceCode?.rawValue ?? "GROUP 11" }
    h2 { definition.name }
    form(
      .class("fp-config-form"), .data("id", value: definition.id.rawValue),
      .data("group", value: String(definition.groupID.rawValue)),
      .data("artworks", value: pickerJSON(artworks))
    ) {
      div(.class("fp-config-grid")) {
        div(.class("fp-config-art")) {
          if let artwork = artworks.first {
            img(.class("fp-active-art"), .src(artwork.versionedPath), .alt(artwork.altText))
          }
        }
        div(.class("fp-fields")) {
          if case .doubleElbow(let ids) = definition.inputRequirement {
            PickerControl(
              field: .init(
                name: "baseFitting", label: "Matching 90° elbow construction",
                choices: ids.compactMap { id in
                  definitions.first { $0.id == id }.map { ($0.id.rawValue, $0.name) }
                }, kind: "select"), values: values)
            if let base = baseDefinition {
              let baseValues = Dictionary(
                uniqueKeysWithValues: PickerFields.defaults(base.defaultInputs).map {
                  ("base." + $0.key, $0.value)
                }
              ).merging(values) { _, new in new }
              for field in PickerFields.fields(base.inputRequirement, base: true) {
                PickerControl(field: field, values: baseValues, prefix: "base.")
              }
            }
          } else {
            for field in PickerFields.fields(definition.inputRequirement) {
              PickerControl(field: field, values: values)
            }
          }
          if definition.groupID == .pannedReturns && artworks.count > 1 {
            PickerControl(
              field: .init(
                name: "artworkView", label: "Drawing view",
                choices: artworks.map {
                  (
                    $0.view.rawValue,
                    $0.view == .individual
                      ? "Individual"
                      : $0.view == .assembly ? "Assembly" : "Assembly with merging flow"
                  )
                }, kind: "select"), values: ["artworkView": values["artworkView"] ?? "individual"])
          }
          if case .fixed = definition.inputRequirement {
            p(.class("fp-note")) { "This fitting has a fixed equivalent length." }
          }
          button(.type(.submit), .class("fp-secondary")) { "Check equivalent length" }
        }
      }
    }
    div(.class("fp-drawing-links")) {
      for artwork in artworks {
        a(.href(artwork.versionedPath), .target(.blank)) {
          "Open \(artwork.view == .individual ? "fitting" : artwork.view == .bendDetail ? "bend R/D detail" : artwork.view.rawValue.replacingOccurrences(of: "-", with: " ")) drawing ↗"
        }
      }
    }
    div(.class("fp-result"), .init(name: "aria-live", value: "polite")) {
      p { "Checking selection…" }
    }
    details(.class("fp-conditions")) {
      summary { "Source conditions" }
      if let velocity = definition.conditions.referenceVelocityFPM {
        p { "Reference velocity: \(velocity) FPM" }
      }
      p {
        "Reference friction rate: \(definition.conditions.frictionRateIWCPer100Feet) IWC per 100 ft"
      }
      for note in definition.conditions.notes { p { note } }
      if let base = baseDefinition { for note in base.conditions.notes { p { note } } }
    }
  }
}

func pickerJSON<T: Encodable>(_ value: T) -> String {
  guard let data = try? JSONEncoder().encode(value),
    let string = String(data: data, encoding: .utf8)
  else { return "null" }
  return string
}
