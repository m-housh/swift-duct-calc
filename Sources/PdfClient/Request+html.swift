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
    style {
      """
      @media print {
        body {
          -webkit-print-color-adjust: exact;
          color-adjust: exact;
          print-color-adjust: exact;
        }
        table td, table th {
          -webkit-print-color-adjust: exact;
        }
      }
      table {
        max-width: 100%;
        border-collapse: collapse;
        margin: 10px auto;
        border: 1px solid #ccc;
      }
      th, td {
        border: 1px solid #ccc;
        padding: 10px;
      }
      tr:nth-child(even) {
        background-color: #f2f2f2;
      }
      .w-full {
        width: 100%;
      }
      .w-half {
        width: 50%;
      }
      .table-footer {
        background-color: #75af4c;
        color: white;
        font-weight: bold;
      }
      .bg-green { 
        background-color: #4CAF50;
        color: white;
      }
      .heating {
        color: red;
      }
      .coolingTotal {
        color: blue;
      }
      .coolingSensible {
        color: cyan;
      }
      .justify-end {
        text-align: end;
      }
      .flex { 
        display: flex; 
        flex-wrap: wrap;
        justify-content: space-between;
        gap: 10px;
      }
      .flex table {
        border: 1px solid #ccc;
        width: 50%;
        margin: 0;
        flex: 1 1 calc(50% - 10px);
      }
      .container {
        display: flex;
        width: 100%;
        gap: 10px;
      }
      .table-container {
        flex: 1;
        min-width: 0;
      }
      .table-container table {
        width: 100%;
        border-collapse: collapse;
      }
      .customerTable {
        width: 50%;
      }
      .section {
        padding: 10px;
      }
      .label {
        font-weight: bold;
      }
      .error {
        color: red;
        font-weight: bold;
      }
      .effectiveLengthGroupTable, .effectiveLengthGroupHeader {
        background-color: white;
        color: black;
        font-weight: bold;
      }
      .headline {
        padding: 10px 0;
      }
      """
    }
  }

  var body: some HTML {
    div {
      h1(.class("headline")) { "Duct Calc" }

      h2 { "Project" }

      div(.class("flex")) {
        table(.class("table customer-table")) {
          tbody {
            tr {
              td { "Name" }
              td { request.project.name }
            }
            tr {
              td { "Street Address" }
              td {
                p {
                  request.project.streetAddress
                  br()
                  request.project.cityStateZipString
                }
              }
            }
          }
        }
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
            // .attributes(.style("height: 140px;"))
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

  struct EffectiveLengthsTable: HTML, Sendable {
    let effectiveLengths: [EffectiveLength]

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("bg-green")) {
            th { "Name" }
            th { "Type" }
            th { "Straight Lengths" }
            th { "Groups" }
            th { "Total" }
          }
        }
        tbody {
          for row in effectiveLengths {
            tr {
              td { row.name }
              td { row.type.rawValue }
              td {
                ul {
                  for length in row.straightLengths {
                    li { length.string() }
                  }
                }
              }
              td {
                EffectiveLengthGroupTable(groups: row.groups)
                  .attributes(.class("w-full"))
              }
              td { row.totalEquivalentLength.string(digits: 0) }
            }
          }
        }
      }
    }

  }

  struct EffectiveLengthGroupTable: HTML, Sendable {
    let groups: [EffectiveLength.Group]

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("effectiveLengthGroupHeader")) {
            th { "Name" }
            th { "Length" }
            th { "Quantity" }
            th { "Total" }
          }
        }
        tbody {
          for row in groups {
            tr {
              td { "\(row.group)-\(row.letter)" }
              td { row.value.string(digits: 0) }
              td { row.quantity.string() }
              td { (row.value * Double(row.quantity)).string(digits: 0) }
            }
          }
        }
      }
    }
  }

  struct RoomsTable: HTML, Sendable {
    let rooms: [Room]
    let projectSHR: Double

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("bg-green")) {
            th { "Name" }
            th { "Heating BTU" }
            th { "Cooling Total BTU" }
            th { "Cooling Sensible BTU" }
            th { "Register Count" }
          }
        }
        tbody {
          for room in rooms {
            tr {
              td { room.name }
              td { room.heatingLoad.string(digits: 0) }
              td { room.coolingTotal.string(digits: 0) }
              td {
                (room.coolingSensible
                  ?? (room.coolingTotal * projectSHR)).string(digits: 0)
              }
              td { room.registerCount.string() }
            }
          }
          // Totals
          // tr(.class("table-footer")) {
          tr {
            td(.class("label")) { "Totals" }
            td(.class("heating label")) {
              rooms.totalHeatingLoad.string(digits: 0)
            }
            td(.class("coolingTotal label")) {
              rooms.totalCoolingLoad.string(digits: 0)
            }
            td(.class("coolingSensible label")) {
              rooms.totalCoolingSensible(shr: projectSHR).string(digits: 0)
            }
            td {}
          }
        }
      }
    }
  }

  struct RegisterDetailTable: HTML, Sendable {
    let rooms: [DuctSizes.RoomContainer]

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("bg-green")) {
            th { "Name" }
            th { "Heating BTU" }
            th { "Cooling BTU" }
            th { "Heating CFM" }
            th { "Cooling CFM" }
            th { "Design CFM" }
          }
        }
        tbody {
          for row in rooms {
            tr {
              td { row.roomName }
              td { row.heatingLoad.string(digits: 0) }
              td { row.coolingLoad.string(digits: 0) }
              td { row.heatingCFM.string(digits: 0) }
              td { row.coolingCFM.string(digits: 0) }
              td { row.designCFM.value.string(digits: 0) }
            }
          }
        }
      }
    }
  }

  struct TrunkTable: HTML, Sendable {
    public let sizes: DuctSizes
    public let type: TrunkSize.TrunkType

    var trunks: [DuctSizes.TrunkContainer] {
      sizes.trunks.filter { $0.type == type }
    }

    var body: some HTML<HTMLTag.table> {
      table {
        thead(.class("bg-green")) {
          tr {
            th { "Name" }
            th { "Dsn CFM" }
            th { "Round Size" }
            th { "Velocity" }
            th { "Final Size" }
            th { "Flex Size" }
            th { "Height" }
            th { "Width" }
          }
        }
        tbody {
          for row in trunks {
            tr {
              td { row.name ?? "" }
              td { row.designCFM.value.string(digits: 0) }
              td { row.ductSize.roundSize.string() }
              td { row.velocity.string() }
              td { row.finalSize.string() }
              td { row.flexSize.string() }
              td { row.ductSize.height?.string() ?? "" }
              td { row.width?.string() ?? "" }
            }
          }
        }
      }
    }
  }

  struct DuctSizesTable: HTML, Sendable {
    let rooms: [DuctSizes.RoomContainer]

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("bg-green")) {
            th { "Name" }
            th { "Dsn CFM" }
            th { "Round Size" }
            th { "Velocity" }
            th { "Final Size" }
            th { "Flex Size" }
            th { "Height" }
            th { "Width" }
          }
        }
        tbody {
          for row in rooms {
            tr {
              td { row.roomName }
              td { row.designCFM.value.string(digits: 0) }
              td { row.roundSize.string() }
              td { row.velocity.string() }
              td { row.flexSize.string() }
              td { row.finalSize.string() }
              td { row.ductSize.height?.string() ?? "" }
              td { row.width?.string() ?? "" }
            }
          }
        }
      }
    }
  }

  struct EquipmentTable: HTML, Sendable {
    let title: String?
    let equipmentInfo: EquipmentInfo

    init(title: String? = nil, equipmentInfo: EquipmentInfo) {
      self.title = title
      self.equipmentInfo = equipmentInfo
    }

    var body: some HTML<HTMLTag.table> {

      table {
        thead {
          tr(.class("bg-green")) {
            th { title ?? "" }
            th(.class("justify-end")) { "Value" }
          }
        }
        tbody {
          tr {
            td { "Static Pressure" }
            td(.class("justify-end")) { equipmentInfo.staticPressure.string() }
          }
          tr {
            td { "Heating CFM" }
            td(.class("justify-end")) { equipmentInfo.heatingCFM.string() }
          }
          tr {
            td { "Cooling CFM" }
            td(.class("justify-end")) { equipmentInfo.coolingCFM.string() }
          }
        }
      }
    }
  }

  struct FrictionRateTable: HTML, Sendable {
    let title: String?
    let componentLosses: [ComponentPressureLoss]
    let frictionRate: FrictionRate
    let totalEquivalentLength: Double
    let displayTotals: Bool

    var sortedLosses: [ComponentPressureLoss] {
      componentLosses.sorted { $0.value > $1.value }
    }

    var body: some HTML<HTMLTag.table> {
      table {
        thead {
          tr(.class("bg-green")) {
            th { title ?? "" }
            th(.class("justify-end")) { "Value" }
          }
        }
        tbody {
          for row in sortedLosses {
            tr {
              td { row.name }
              td(.class("justify-end")) { row.value.string() }
            }
          }
          if displayTotals {
            tr {
              td(.class("label justify-end")) { "Available Static Pressure" }
              td(.class("justify-end")) { frictionRate.availableStaticPressure.string() }
            }
            tr {
              td(.class("label justify-end")) { "Total Equivalent Length" }
              td(.class("justify-end")) { totalEquivalentLength.string() }
            }
            tr {
              td(.class("label justify-end")) { "Friction Rate Design Value" }
              td(.class("justify-end")) { frictionRate.value.string() }
            }
          }
        }
      }
    }
  }
}

extension Project {
  var cityStateZipString: String {
    return "\(city), \(state) \(zipCode)"
  }
}
