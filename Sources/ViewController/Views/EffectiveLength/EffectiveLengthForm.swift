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

// TODO: Add patch / update capability

struct EffectiveLengthForm: HTML, Sendable {

  static func id(_ equivalentLength: EffectiveLength?) -> String {
    let base = "equivalentLengthForm"
    guard let equivalentLength else { return base }
    return "\(base)_\(equivalentLength.id.uuidString.replacing("-", with: ""))"
  }

  let projectID: Project.ID
  let dismiss: Bool
  let type: EffectiveLength.EffectiveLengthType
  let effectiveLength: EffectiveLength?

  var id: String { Self.id(effectiveLength) }

  init(
    projectID: Project.ID,
    dismiss: Bool,
    type: EffectiveLength.EffectiveLengthType = .supply
  ) {
    self.projectID = projectID
    self.dismiss = dismiss
    self.type = type
    self.effectiveLength = nil
  }

  init(
    effectiveLength: EffectiveLength
  ) {
    self.dismiss = true
    self.type = effectiveLength.type
    self.projectID = effectiveLength.projectID
    self.effectiveLength = effectiveLength

  }

  var body: some HTML {
    ModalForm(
      id: id,
      dismiss: dismiss
    ) {
      h1(.class("text-2xl font-bold")) { "Effective Length" }
      div(.id("formStep_\(id)")) {
        StepOne(projectID: projectID, effectiveLength: effectiveLength)
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
        .hx.target("#formStep_\(EffectiveLengthForm.id(effectiveLength))"),
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
        .hx.target("#formStep_\(EffectiveLengthForm.id(effectiveLength))"),
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
        div(.id("straightLengths"), .class("space-y-4")) {
          if let effectiveLength {
            for length in effectiveLength.straightLengths {
              StraightLengthField(value: length)
            }
          } else {
            StraightLengthField()
          }
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
      if effectiveLength != nil {
        return SiteRoute.View.router.path(
          for: .project(.detail(projectID, .equivalentLength(.index))))
      } else {
        let baseRoute = SiteRoute.View.router.path(
          for: .project(.detail(projectID, .equivalentLength(.index)))
        )
        return "\(baseRoute)/stepThree"
      }
    }

    var body: some HTML {
      form(
        .class("space-y-4"),
        effectiveLength == nil
          ? .hx.post(route)
          : .hx.patch(route),
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

        div(.class("grid grid-cols-5 gap-2")) {
          Label("Group")
          Label("Letter")
          Label("Length")
          Label("Quantity")
            .attributes(.class("col-span-2"))
        }

        div(.id("groups"), .class("space-y-4")) {
          if let effectiveLength {
            for group in effectiveLength.groups {
              GroupField(style: effectiveLength.type, group: group)
            }
          } else {
            GroupField(style: stepTwo.type)
          }
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
      .attributes(.type(.number), .min("0"), .autofocus, .required, .value(value))

      TrashButton()
        .attributes(.data("remove", value: "true"))
    }
    .attributes(.hx.ext("remove"), .class("space-x-4"))
  }
}

struct GroupField: HTML, Sendable {

  let style: EffectiveLength.EffectiveLengthType
  let group: EffectiveLength.Group?

  init(style: EffectiveLength.EffectiveLengthType, group: EffectiveLength.Group? = nil) {
    self.style = style
    self.group = group
  }

  var body: some HTML {
    div(.class("grid grid-cols-5 gap-2")) {
      GroupSelect(style: style)
      Input(name: "group[letter]", placeholder: "Letter")
        .attributes(.type(.text), .autofocus, .required, .value(group?.letter))
      Input(name: "group[length]", placeholder: "Length")
        .attributes(.type(.number), .min("0"), .required, .value(group?.value))
      Input(name: "group[quantity]", placeholder: "Quantity")
        .attributes(.type(.number), .min("1"), .value("1"), .required, .value(group?.quantity ?? 1))
      div(.class("flex justify-end")) {
        TrashButton()
          .attributes(.data("remove", value: "true"), .class("mx-2"))
      }
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
