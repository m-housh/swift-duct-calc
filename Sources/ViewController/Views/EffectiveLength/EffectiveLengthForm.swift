import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: May need a multi-step form were the the effective length type is
//       determined before groups selections are made in order to use the
//       appropriate select field values when the type is supply vs. return.
//       Currently when the select field is changed it doesn't change the group
//       I can get it to add a new one.

// TODO: Add back buttons / capability??

struct EffectiveLengthForm: HTML, Sendable {
  static let id = "equivalentLengthForm"

  let projectID: Project.ID
  let dismiss: Bool
  let type: EffectiveLength.EffectiveLengthType

  init(
    projectID: Project.ID,
    dismiss: Bool,
    type: EffectiveLength.EffectiveLengthType = .supply
  ) {
    self.projectID = projectID
    self.dismiss = dismiss
    self.type = type
  }

  var body: some HTML {
    ModalForm(id: Self.id, dismiss: dismiss) {
      h1(.class("text-2xl font-bold")) { "Effective Length" }
      div(.id("formStep")) {
        StepOne(projectID: projectID, effectiveLength: nil)
      }
    }
  }

  struct StepOne: HTML, Sendable {
    let projectID: Project.ID
    let effectiveLength: EffectiveLength?

    var route: String {
      let baseRoute = SiteRoute.View.router.path(
        for: .project(.detail(projectID, .equivalentLength(.index)))
      )
      return "\(baseRoute)/stepOne"
    }

    var body: some HTML {
      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("#formStep"),
        .hx.swap(.innerHTML)
      ) {
        if let id = effectiveLength?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }
        Input(id: "name", placeholder: "Name")
          .attributes(.type(.text), .required, .autofocus, .value(effectiveLength?.name))

        GroupTypeSelect(projectID: projectID, selected: effectiveLength?.type ?? .supply)

        Row {
          div {}
          SubmitButton(title: "Next")
        }
      }
    }
  }

  struct StepTwo: HTML, Sendable {
    let projectID: Project.ID
    let stepOne: SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepOne
    let effectiveLength: EffectiveLength?

    var route: String {
      let baseRoute = SiteRoute.View.router.path(
        for: .project(.detail(projectID, .equivalentLength(.index)))
      )
      return "\(baseRoute)/stepTwo"
    }

    var body: some HTML {
      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("#formStep"),
        .hx.swap(.innerHTML)
      ) {
        if let id = effectiveLength?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }
        input(.class("hidden"), .name("name"), .value(stepOne.name))
        input(.class("hidden"), .name("type"), .value(stepOne.type.rawValue))

        Row {
          Label { "Straigth Lengths" }
          button(
            .type(.button),
            .hx.get(
              route: .project(.detail(projectID, .equivalentLength(.field(.straightLength))))
            ),
            .hx.target("#straightLengths"),
            .hx.swap(.beforeEnd)
          ) {
            SVG(.circlePlus)
          }
        }
        div(.id("straightLengths")) {
          StraightLengthField()
        }

        Row {
          div {}
          SubmitButton(title: "Next")
        }
      }
    }
  }

  struct StepThree: HTML, Sendable {
    let projectID: Project.ID
    let effectiveLength: EffectiveLength?
    let stepTwo: SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepTwo

    var route: String {
      let baseRoute = SiteRoute.View.router.path(
        for: .project(.detail(projectID, .equivalentLength(.index)))
      )
      return "\(baseRoute)/stepThree"
    }

    var body: some HTML {
      form(
        .class("space-y-4"),
        .hx.post(route),
        .hx.target("body"),
        .hx.swap(.outerHTML)
      ) {
        if let id = effectiveLength?.id {
          input(.class("hidden"), .name("id"), .value("\(id)"))
        }
        input(.class("hidden"), .name("name"), .value(stepTwo.name))
        input(.class("hidden"), .name("type"), .value(stepTwo.type.rawValue))
        for length in stepTwo.straightLengths {
          input(.class("hidden"), .name("straightLengths"), .value("\(length)"))
        }

        Row {
          Label { "Groups" }
          button(
            .type(.button),
            .hx.get(
              route: .project(
                .detail(projectID, .equivalentLength(.field(.group, style: stepTwo.type))))
            ),
            .hx.target("#groups"),
            .hx.swap(.beforeEnd)
          ) {
            SVG(.circlePlus)
          }
        }
        div(.id("groups"), .class("space-y-4")) {
          GroupField(style: stepTwo.type)
        }
        Row {
          div {}
          SubmitButton()
        }
      }
    }
  }
}

struct StraightLengthField: HTML, Sendable {
  let value: Int?

  init(value: Int? = nil) {
    self.value = value
  }

  var body: some HTML<HTMLTag.div> {
    Row {
      Input(
        name: "straightLengths",
        placeholder: "Length"
      )
      .attributes(.type(.number), .min("0"), .autofocus, .required)

      TrashButton()
        .attributes(.data("remove", value: "true"))
    }
    .attributes(.hx.ext("remove"))
  }
}

struct GroupField: HTML, Sendable {

  let style: EffectiveLength.EffectiveLengthType

  var body: some HTML {
    Row {
      GroupSelect(style: style)
      Input(name: "group[letter]", placeholder: "Letter")
        .attributes(.type(.text), .autofocus, .required)
      Input(name: "group[length]", placeholder: "Length")
        .attributes(.type(.number), .min("0"), .required)
      Input(name: "group[quantity]", placeholder: "Quantity")
        .attributes(.type(.number), .min("1"), .value("1"), .required)
      TrashButton()
        .attributes(.data("remove", value: "true"))
    }
    .attributes(.class("space-x-2"), .hx.ext("remove"))
  }
}

struct GroupSelect: HTML, Sendable {

  let style: EffectiveLength.EffectiveLengthType

  var body: some HTML {
    select(
      .name("group[group]"),
      .class("select")
    ) {
      for value in style.selectOptions {
        option(.value("\(value)")) { "\(value)" }
      }
    }
  }

}

struct GroupTypeSelect: HTML, Sendable {

  let projectID: Project.ID
  let selected: EffectiveLength.EffectiveLengthType

  var body: some HTML<HTMLTag.select> {
    select(.class("select"), .name("type"), .id("type")) {
      for value in EffectiveLength.EffectiveLengthType.allCases {
        option(
          .value("\(value.rawValue)"),
        ) { value.title }
        .attributes(.selected, when: value == selected)
      }
    }
  }
}

extension EffectiveLength.EffectiveLengthType {

  var title: String { rawValue.capitalized }

  var selectOptions: [Int] {
    switch self {
    case .return:
      return [5, 6, 7, 8, 10, 11, 12]
    case .supply:
      return [1, 2, 4, 8, 9, 11, 12]
    }
  }
}
