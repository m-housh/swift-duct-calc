import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Add back buttons / capability??

struct EffectiveLengthForm: HTML, Sendable {

  static func id(_ equivalentLength: EquivalentLength?) -> String {
    let base = "equivalentLengthForm"
    guard let equivalentLength else { return base }
    return "\(base)_\(equivalentLength.id.uuidString.replacing("-", with: ""))"
  }

  let projectID: Project.ID
  let dismiss: Bool
  let type: EquivalentLength.EffectiveLengthType
  let effectiveLength: EquivalentLength?

  var id: String { Self.id(effectiveLength) }

  init(
    projectID: Project.ID,
    dismiss: Bool,
    type: EquivalentLength.EffectiveLengthType = .supply
  ) {
    self.projectID = projectID
    self.dismiss = dismiss
    self.type = type
    self.effectiveLength = nil
  }

  init(
    effectiveLength: EquivalentLength
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
      div(.id("formStep_\(id)"), .class("mt-4")) {
        StepOne(projectID: projectID, effectiveLength: effectiveLength)
      }
    }
  }

  struct StepOne: HTML, Sendable {
    let projectID: Project.ID
    let effectiveLength: EquivalentLength?

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

        LabeledInput(
          "Name",
          .name("name"),
          .type(.text),
          .value(effectiveLength?.name),
          .required,
          .autofocus
        )

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
    let effectiveLength: EquivalentLength?

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
    let effectiveLength: EquivalentLength?
    let stepTwo: SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepTwo

    var route: String {
      let baseRoute = SiteRoute.View.router.path(
        for: .project(.detail(projectID, .equivalentLength(.index)))
      )

      if let effectiveLength {
        return baseRoute.appendingPath(effectiveLength.id)
      } else {
        return baseRoute.appendingPath("stepThree")
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

        a(
          .href("/files/ManD.Groups.pdf"),
          .target(.blank),
          .class("btn btn-link")
        ) {
          "Click here for Manual-D groups reference."
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
      LabeledInput(
        "Length",
        .name("straightLengths"),
        .type(.number),
        .value(value),
        .placeholder("10"),
        .min("0"),
        .autofocus,
        .required
      )
      TrashButton()
        .attributes(.data("remove", value: "true"))
    }
    .attributes(.hx.ext("remove"), .class("space-x-4"))
  }
}

struct GroupField: HTML, Sendable {

  let style: EquivalentLength.EffectiveLengthType
  let group: EquivalentLength.Group?

  init(style: EquivalentLength.EffectiveLengthType, group: EquivalentLength.Group? = nil) {
    self.style = style
    self.group = group
  }

  var body: some HTML {
    div(.class("grid grid-cols-3 gap-2 p-2 border rounded-lg shadow-sm")) {
      GroupSelect(style: style)

      LabeledInput(
        "Letter",
        .name("group[letter]"),
        .type(.text),
        .value(group?.letter),
        .placeholder("a"),
        .required
      )

      LabeledInput(
        "Length",
        .name("group[length]"),
        .type(.number),
        .value(group?.value),
        .placeholder("10"),
        .min("0"),
        .required
      )

      LabeledInput(
        "Quantity",
        .name("group[quantity]"),
        .type(.number),
        .value(group?.quantity ?? 1),
        .min("1"),
        .required
      )
      .attributes(.class("col-span-2"))

      TrashButton()
        .attributes(
          .data("remove", value: "true"),
          .class("me-2 btn-block")
        )
    }
    .attributes(.class("space-x-2"), .hx.ext("remove"))
  }
}

struct GroupSelect: HTML, Sendable {

  let style: EquivalentLength.EffectiveLengthType

  var body: some HTML {
    label(.class("select")) {
      span(.class("label")) { "Group" }
      select(
        .name("group[group]"),
        .autofocus
      ) {
        for value in style.selectOptions {
          option(.value("\(value)")) { "\(value)" }
        }
      }
    }
  }

}

struct GroupTypeSelect: HTML, Sendable {

  let projectID: Project.ID
  let selected: EquivalentLength.EffectiveLengthType

  var body: some HTML<HTMLTag.label> {
    label(.class("select w-full")) {
      span(.class("label")) { "Type" }
      select(.name("type"), .id("type")) {
        for value in EquivalentLength.EffectiveLengthType.allCases {
          option(
            .value("\(value.rawValue)"),
          ) { value.title }
          .attributes(.selected, when: value == selected)
        }
      }
    }
  }
}

extension EquivalentLength.EffectiveLengthType {

  var title: String { rawValue.capitalized }

  var selectOptions: [Int] {
    switch self {
    case .return:
      return [5, 6, 7, 8, 10, 11, 12]
    case .supply:
      return [1, 2, 3, 4, 8, 9, 11, 12]
    }
  }
}
