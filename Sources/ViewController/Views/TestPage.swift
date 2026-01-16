import Dependencies
import Elementary
import Foundation
import ManualDCore
import Styleguide

struct TestPage: HTML, Sendable {
  // let ductSizes: DuctSizes

  var body: some HTML {
    div {}
    // div(.class("overflow-auto")) {
    //   DuctSizingView.TrunkTable(ductSizes: ductSizes)
    //
    //   Row {
    //     h2(.class("text-2xl font-bold")) { "Trunk Sizes" }
    //
    //     PlusButton()
    //       .attributes(
    //         .class("me-6"),
    //         .showModal(id: TrunkSizeForm.id())
    //       )
    //   }
    //   .attributes(.class("mt-6"))
    //
    //   div(.class("divider -mt-2")) {}
    //
    //   DuctSizingView.TrunkTable(ductSizes: ductSizes)
    // }
  }
}
