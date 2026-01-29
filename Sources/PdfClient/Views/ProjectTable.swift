import Elementary
import ManualDCore

struct ProjectTable: HTML, Sendable {
  let project: Project

  var body: some HTML<HTMLTag.table> {
    table {
      tbody {
        tr {
          td(.class("label")) { "Name" }
          td { project.name }
        }
        tr {
          td(.class("label")) { "Address" }
          td {
            p {
              project.streetAddress
              br()
              project.cityStateZipString
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
