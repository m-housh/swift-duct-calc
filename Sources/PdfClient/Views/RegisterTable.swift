import Elementary
import ManualDCore

struct RegisterDetailTable: HTML, Sendable {
  let rooms: [DuctSizes.RoomContainer]

  var body: some HTML<HTMLTag.table> {
    table {
      thead {
        tr {
          ReportColumn("Room / register")
          ReportColumn("Heating", unit: "BTU/h")
          ReportColumn("Cooling sensible", unit: "BTU/h")
          ReportColumn("Heating", unit: "CFM")
          ReportColumn("Cooling", unit: "CFM")
          ReportColumn("Design", unit: "CFM")
        }
      }
      tbody {
        for row in rooms {
          tr {
            td { row.reportLabel }
            td { row.heatingLoad.string(digits: 0) }
            td { row.coolingLoad.string(digits: 0) }
            td { row.heatingCFM.string(digits: 0) }
            td { row.coolingCFM.string(digits: 0) }
            td(.class("selected")) { row.designCFM.value.string(digits: 0) }
          }
        }
        if rooms.isEmpty {
          tr { td(.custom(name: "colspan", value: "6")) { "No register airflow." } }
        }
      }
    }
  }
}
