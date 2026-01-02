import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthForm: HTML, Sendable {
  let dismiss: Bool

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
          select(
            .id("type"), .name("type"),
            .class("w-full border rounded-md")
          ) {
            option(.value("supply")) { "Supply" }
            option(.value("return")) { "Return" }
          }
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
            .hx.get(route: .effectiveLength(.field(.group))),
            .hx.target("#groups"),
            .hx.swap(.beforeEnd)
          ) {
            SVG(.circlePlus)
          }
        }
        div(.id("groups"), .class("space-y-4")) {
          GroupField()
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

  var body: some HTML {
    Row {
      Input(name: "group[][group]", placeholder: "Group")
        .attributes(.type(.number), .min("0"))
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
