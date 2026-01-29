import Elementary
import ManualDCore

extension PdfClient.Request {

  func toHTML() -> (some HTML & Sendable) {
    PdfDocument(request: self)
  }
}

struct PdfDocument: HTMLDocument {

  let title = "Duct Calc"
  let lang = "en"
  let request: PdfClient.Request

  var head: some HTML {
    link(.rel(.stylesheet), .href("/css/pdf.css"))
  }

  var body: some HTML {
    div {
      // h1(.class("headline")) { "Duct Calc" }

      h2 { "Project" }

      div(.class("flex")) {
        ProjectTable(project: request.project)
        // HACK:
        table {}
      }

      div(.class("section")) {
        div(.class("flex")) {
          h2 { "Equipment" }
          h2 { "Friction Rate" }
        }
        div(.class("flex")) {
          div(.class("container")) {
            div(.class("table-container")) {
              EquipmentTable(title: "Equipment", equipmentInfo: request.equipmentInfo)
            }
            div(.class("table-container")) {
              FrictionRateTable(
                title: "Friction Rate",
                componentLosses: request.componentLosses,
                frictionRate: request.frictionRate,
                totalEquivalentLength: request.totalEquivalentLength,
                displayTotals: false
              )
            }
          }
        }
        if let error = request.frictionRate.error {
          div(.class("section")) {
            p(.class("error")) {
              error.reason
              for resolution in error.resolutions {
                br()
                "  * \(resolution)"
              }
            }
          }
        }
      }
      div(.class("section")) {
        h2 { "Duct Sizes" }
        DuctSizesTable(rooms: request.ductSizes.rooms)
          .attributes(.class("w-full"))
      }

      div(.class("section")) {
        h2 { "Supply Trunk / Run Outs" }
        TrunkTable(sizes: request.ductSizes, type: .supply)
          .attributes(.class("w-full"))
      }

      div(.class("section")) {
        h2 { "Return Trunk / Run Outs" }
        TrunkTable(sizes: request.ductSizes, type: .return)
          .attributes(.class("w-full"))
      }

      div(.class("section")) {
        h2 { "Total Equivalent Lengths" }
        EffectiveLengthsTable(effectiveLengths: [
          request.maxSupplyTEL, request.maxReturnTEL,
        ])
        .attributes(.class("w-full"))
      }

      div(.class("section")) {
        h2 { "Register Detail" }
        RegisterDetailTable(rooms: request.ductSizes.rooms)
          .attributes(.class("w-full"))
      }

      div(.class("section")) {
        h2 { "Room Detail" }
        RoomsTable(rooms: request.rooms, projectSHR: request.projectSHR)
          .attributes(.class("w-full"))
      }
    }

  }

}
