import Elementary
import Foundation
import ManualDCore

struct PickerCatalogGroup: Sendable {
  let group: Fitting.Group
  let entries: [(Fitting.Definition, Fitting.Artwork?)]
}

struct FittingPickerView: HTML, Sendable {
  let pathType: Fitting.PathType
  let groups: [PickerCatalogGroup]

  var body: some HTML {
    link(.rel(.stylesheet), .href("/css/fitting-picker.css"))
    script(.src("/js/fitting-picker.js"), .defer) {}
    div(.class("fp"), .id("fitting-picker"), .data("path-type", value: pathType.rawValue)) {
      header(.class("fp-top")) {
        a(.href("/"), .class("fp-brand")) { "DUCT CALC" }
        span(.class("fp-preview")) { "Fitting picker · Live preview" }
        a(.href("/projects")) { "Projects ↗" }
      }
      div(.class("fp-intro")) {
        div {
          p(.class("fp-eyebrow")) { "BUILD YOUR DUCT PATH" }
          h1 { "Every turn counts." }
          p { "Choose a fitting, check its conditions, and add it to your path." }
        }
        div(.class("fp-path-switch"), .init(name: "aria-label", value: "Path type")) {
          a(.href("/fittings?type=supply"), .class(pathType == .supply ? "is-active" : "")) {
            "Supply"
          }
          a(.href("/fittings?type=return"), .class(pathType == .return ? "is-active" : "")) {
            "Return"
          }
        }
      }
      p(.class("fp-notice")) {
        "This preview keeps a draft in your browser tab. Saving to a project comes next."
      }
      div(.class("fp-workspace")) {
        section(.class("fp-catalog"), .init(name: "aria-label", value: "Fitting catalog")) {
          div(.class("fp-catalog-tools")) {
            label {
              span(.class("fp-sr-only")) { "Search fittings" }
              input(
                .type(.search), .id("fp-search"), .placeholder("Search by code or fitting name…"))
            }
            button(.type(.button), .id("fp-reference-open"), .class("fp-secondary")) {
              "Quick entry"
            }
          }
          nav(.class("fp-group-rail"), .init(name: "aria-label", value: "Fitting groups")) {
            for (index, section) in groups.enumerated() {
              button(
                .type(.button), .data("group", value: String(section.group.id.rawValue)),
                .class(index == 0 ? "is-active" : ""),
                .init(name: "aria-pressed", value: index == 0 ? "true" : "false")
              ) {
                span { "\(section.group.id.rawValue)" }
                "\(section.group.title)"
              }
            }
          }
          for (index, section) in groups.enumerated() {
            div(.class("fp-group"), .data("panel", value: String(section.group.id.rawValue))) {
              div(.class("fp-group-heading")) {
                h2 { section.group.title }
                span { "\(section.entries.count) choices" }
              }
              div(.class("fp-card-grid")) {
                for (definition, artwork) in section.entries {
                  button(
                    .type(.button), .class("fp-card"),
                    .data("fitting-id", value: definition.id.rawValue),
                    .data("fitting-group", value: String(definition.groupID.rawValue)),
                    .data(
                      "search",
                      value: "\(definition.sourceCode?.rawValue ?? "11") \(definition.name)")
                  ) {
                    div(.class("fp-card-image")) {
                      if let artwork {
                        img(
                          .src(artwork.versionedPath), .alt(artwork.altText),
                          .init(name: "loading", value: "lazy"))
                      }
                    }
                    div(.class("fp-card-caption")) {
                      span(.class("fp-code")) { definition.sourceCode?.rawValue ?? "Group 11" }
                      span { definition.name }
                    }
                  }
                }
              }
            }.attributes(.hidden, when: index != 0)
          }
          p(.id("fp-no-matches"), .hidden) { "No matching fittings in this group." }
        }
        aside(.class("fp-path"), .init(name: "aria-label", value: "Draft path")) {
          div(.class("fp-path-heading")) {
            h2 { "Your \(pathType.rawValue) path" }
            span(.id("fp-count")) { "0 fittings" }
          }
          label(.class("fp-straight")) {
            span { "Straight duct (ft)" }
            input(.id("fp-straight"), .type(.number), .min("0"), .step("any"), .value("0"))
          }
          ol(.id("fp-rows")) {}
          div(.id("fp-empty"), .class("fp-empty")) {
            span { "↳" }
            p { "Start with your first fitting." }
            small { "Your selections and quantities will appear here." }
          }
          p(.id("fp-duplicate-warning"), .class("fp-note"), .hidden) {}
          div(.class("fp-total"), .init(name: "aria-live", value: "polite")) {
            span { "Total equivalent length" }
            strong(.id("fp-total")) { "0 ft" }
          }
          div(.class("fp-path-actions")) {
            button(.type(.button), .id("fp-download"), .class("fp-primary"), .disabled) {
              "Download draft"
            }
            button(.type(.button), .id("fp-clear"), .class("fp-quiet")) { "Clear path" }
          }
        }
      }
      dialog(
        .id("fp-dialog"), .class("fp-dialog"),
        .init(name: "aria-labelledby", value: "fp-dialog-title")
      ) {
        button(
          .type(.button), .class("fp-dialog-close"), .data("close-picker", value: "true"),
          .init(name: "aria-label", value: "Close fitting")
        ) { "×" }
        div(.id("fp-config")) { h2(.id("fp-dialog-title")) { "Choose a fitting" } }
      }
      dialog(
        .id("fp-reference-dialog"), .class("fp-dialog fp-reference"),
        .init(name: "aria-labelledby", value: "fp-reference-title")
      ) {
        button(
          .type(.button), .class("fp-dialog-close"), .data("close-reference", value: "true"),
          .init(name: "aria-label", value: "Close quick entry")
        ) { "×" }
        h2(.id("fp-reference-title")) { "Quick reference entry" }
        p {
          "Enter a code and the length from your reference. Your supplied length will be preserved."
        }
        form(.id("fp-reference-form")) {
          label {
            "Fitting code"
            input(.name("code"), .placeholder("4AG"), .required)
          }
          label {
            "Equivalent length per fitting (ft)"
            input(.name("length"), .type(.number), .min("0.001"), .step("any"), .required)
          }
          button(.type(.submit), .class("fp-primary")) { "Check entry" }
        }
        div(.id("fp-reference-result"), .init(name: "aria-live", value: "polite")) {}
      }
      div(.id("fp-announcement"), .class("fp-sr-only"), .init(name: "aria-live", value: "polite")) {
      }
    }
  }
}

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
    p(.class("fp-eyebrow")) { definition.sourceCode?.rawValue ?? "GROUP 11" }
    h2(.id("fp-dialog-title")) { definition.name }
    form(
      .id("fp-config-form"), .data("id", value: definition.id.rawValue),
      .data("group", value: String(definition.groupID.rawValue)),
      .data("artworks", value: pickerJSON(artworks))
    ) {
      div(.class("fp-config-grid")) {
        div(.class("fp-config-art")) {
          if let artwork = artworks.first {
            img(.id("fp-active-art"), .src(artwork.versionedPath), .alt(artwork.altText))
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
    div(.id("fp-result"), .init(name: "aria-live", value: "polite")) { p { "Checking selection…" } }
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

struct PickerControl: HTML, Sendable {
  let field: PickerField
  let values: [String: String]
  var prefix = ""
  var name: String { prefix + field.name }
  var body: some HTML {
    if field.kind == "hidden" {
      input(.type(.hidden), .name(name), .value("90"))
    } else {
      label(
        .class(field.kind == "checkbox" ? "fp-checkbox" : "fp-field"), .data("field", value: name)
      ) {
        if field.kind == "checkbox" {
          input(.type(.checkbox), .name(name), .value("true")).attributes(
            .checked, when: values[name] == "true")
          span { field.label }
        } else {
          span { field.label }
          if let choices = field.choices {
            select(.name(name)) {
              option(.value("")) { "Choose…" }.attributes(
                .selected, when: values[name, default: ""].isEmpty)
              for (value, label) in choices {
                option(.value(value)) { label }.attributes(.selected, when: values[name] == value)
              }
            }
          } else {
            input(
              .type(.number), .name(name), .value(values[name, default: ""]), .min("0"),
              .step(field.kind == "integer" ? "1" : "any"))
          }
        }
        if !field.help.isEmpty { small { field.help } }
      }
    }
  }
}

func pickerJSON<T: Encodable>(_ value: T) -> String {
  guard let data = try? JSONEncoder().encode(value),
    let string = String(data: data, encoding: .utf8)
  else { return "null" }
  return string
}
