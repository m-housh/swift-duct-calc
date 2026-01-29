import Elementary
import ManualDCore

struct EffectiveLengthsTable: HTML, Sendable {
  let effectiveLengths: [EquivalentLength]

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
  let groups: [EquivalentLength.Group]

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
