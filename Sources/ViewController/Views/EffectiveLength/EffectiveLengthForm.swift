import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthForm: HTML, Sendable {

  var body: some HTML {
    div(
      .id("effectiveLengthForm"),
      .class(
        """
        fixed top-40 left-[25vw] w-1/2 z-50 text-gray-800
        bg-gray-200 border border-gray-400 
        rounded-lg shadow-lg mx-10
        """
      )
    ) {
      h1(.class("text-2xl font-bold")) { "Effective Length" }
      form(.class("space-y-4 p-4")) {
        // FIX: Add fields

        Row {
          div {}
          div {
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
