import Elementary
import ManualDCore

struct DuctSizesTable: HTML, Sendable {
  let rooms: [DuctSizes.RoomContainer]

  var body: some HTML<HTMLTag.table> {
    table(.class("duct-sizes")) {
      thead {
        tr {
          ReportColumn("Room / register")
          DuctSizeColumns()
        }
      }
      tbody {
        for row in rooms {
          tr {
            td { row.reportLabel }
            DuctSizeCells(size: row.ductSize)
          }
        }
        if rooms.isEmpty { tr { td(.custom(name: "colspan", value: "8")) { "No room ducts." } } }
      }
    }
  }
}

struct ReportColumn: HTML {
  let name: String
  let unit: String?
  init(_ name: String, unit: String? = nil) {
    self.name = name
    self.unit = unit
  }
  var body: some HTML<HTMLTag.th> {
    th(.scope(.col)) {
      name
      if let unit { small { unit } }
    }
  }
}

struct DuctSizeColumns: HTML {
  var body: some HTML {
    ReportColumn("Design", unit: "CFM")
    ReportColumn("Round", unit: "in.")
    ReportColumn("Velocity", unit: "FPM")
    ReportColumn("Final round", unit: "in.")
    ReportColumn("Flex", unit: "in.")
    ReportColumn("Height", unit: "in.")
    ReportColumn("Width", unit: "in.")
  }
}

struct DuctSizeCells: HTML {
  let size: DuctSizes.SizeContainer
  private var rectangular: Bool { size.height != nil && size.width != nil }
  var body: some HTML {
    td { size.designCFM.value.string(digits: 0) }
    td { size.roundSize.string() }
    td { size.velocity.string() }
    td(.class(rectangular ? "" : "selected")) { size.finalSize.string() }
    td { size.flexSize.string() }
    td(.class(rectangular ? "selected" : "")) { size.height?.string() ?? "—" }
    td(.class(rectangular ? "selected" : "")) { size.width?.string() ?? "—" }
  }
}

extension DuctSizes.RoomContainer {
  var reportLabel: String {
    [roomLevel?.label, "\(roomName) / \(roomRegister)"].compactMap { $0 }.joined(separator: " · ")
  }
}
