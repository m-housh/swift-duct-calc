import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: May need a multi-step form were the the effective length type is
//       determined before groups selections are made in order to use the
//       appropriate select field values when the type is supply vs. return.
//       Currently when the select field is changed it doesn't change the group
//       I can get it to add a new one.

struct EffectiveLengthForm: HTML, Sendable {
  let dismiss: Bool
  let type: EffectiveLength.EffectiveLengthType

  init(dismiss: Bool, type: EffectiveLength.EffectiveLengthType = .supply) {
    self.dismiss = dismiss
    self.type = type
  }

  var body: some HTML {
    ModalForm(id: "effectiveLengthForm", dismiss: dismiss) {
      h1(.class("text-2xl font-bold")) { "Effective Length" }
      form(.class("space-y-4 p-4")) {
        div {
          label(.for("name")) { "Name" }
          Input(id: "name", placeholder: "Name")
            .attributes(.type(.text), .required, .autofocus)
        }
        div {
          label(.for("type")) { "Type" }
          GroupTypeSelect(selected: type)
            .attributes(.class("w-full border rounded-md"))
        }
        Row {
          Label { "Straigth Lengths" }
          button(
            .type(.button),
            .hx.get(route: .effectiveLength(.field(.straightLength))),
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
          Label { "Groups" }
          button(
            .type(.button),
            .hx.get(route: .effectiveLength(.field(.group, style: type))),
            .hx.target("#groups"),
            .hx.swap(.beforeEnd)
          ) {
            SVG(.circlePlus)
          }
        }
        div(.id("groups"), .class("space-y-4")) {
          GroupField(style: type)
        }

        Row {
          div {}
          div(.class("space-x-4")) {
            CancelButton()
              .attributes(
                .hx.get(route: .effectiveLength(.form(dismiss: true))),
                .hx.target("#effectiveLengthForm"),
                .hx.swap(.outerHTML)
              )
            SubmitButton()
          }
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
    div(.class("pb-4")) {
      Input(
        name: "straightLengths[]",
        placeholder: "Length"
      )
      .attributes(.type(.number), .min("0"))
    }
  }
}

struct GroupField: HTML, Sendable {

  let style: EffectiveLength.EffectiveLengthType

  var body: some HTML {
    Row {
      // Input(name: "group[][group]", placeholder: "Group")
      //   .attributes(.type(.number), .min("0"))
      GroupSelect(style: style)
      Input(name: "group[][letter]", placeholder: "Letter")
        .attributes(.type(.text))
      Input(name: "group[][length]", placeholder: "Length")
        .attributes(.type(.number), .min("0"))
      Input(name: "group[][quantity]", placeholder: "Quantity")
        .attributes(.type(.number), .min("1"), .value("1"))
    }
    .attributes(.class("space-x-2"))
  }
}

struct GroupSelect: HTML, Sendable {

  let style: EffectiveLength.EffectiveLengthType

  var body: some HTML {
    select(
      .name("group")
    ) {
      for value in style.selectOptions {
        option(.value("\(value)")) { "\(value)" }
      }
    }
  }

}

struct GroupTypeSelect: HTML, Sendable {

  var selected: EffectiveLength.EffectiveLengthType

  var body: some HTML<HTMLTag.select> {
    select(.name("type"), .id("type")) {
      for value in EffectiveLength.EffectiveLengthType.allCases {
        option(
          .value("\(value.rawValue)"),
          .hx.get(route: .effectiveLength(.field(.group, style: value))),
          .hx.target("#groups"),
          .hx.swap(.beforeEnd),
          .hx.trigger(.event(.change).from("#type"))
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
