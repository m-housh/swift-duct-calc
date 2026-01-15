import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsTable: HTML, Sendable {

  let effectiveLengths: [EffectiveLength]

  private var sortedLengths: [EffectiveLength] {
    effectiveLengths.sorted {
      $0.totalEquivalentLength > $1.totalEquivalentLength
    }
    .sorted {
      $0.type.rawValue > $1.type.rawValue
    }
  }

  var body: some HTML<HTMLTag.table> {
    table(.class("table table-zebra text-lg")) {
      thead {
        tr(.class("text-lg")) {
          th { "Type" }
          th { "Name" }
          th { "Straight Lengths" }
          th {
            div(.class("grid grid-cols-3 gap-2 min-w-[220px]")) {
              div(.class("flex justify-center col-span-3")) {
                "Groups"
              }
              div { "Group" }
              div(.class("flex justify-center")) {
                "T.E.L."
              }
              div(.class("flex justify-end")) {
                "Quantity"
              }
            }
          }
          th {
            div(.class("flex justify-end me-[140px]")) {
              "T.E.L."
            }
          }
        }
      }
      tbody {
        for row in sortedLengths {
          EffectiveLenghtRow(effectiveLength: row)
        }
      }

    }
  }

  struct EffectiveLenghtRow: HTML, Sendable {

    let effectiveLength: EffectiveLength

    private var deleteRoute: SiteRoute.View {
      .project(
        .detail(
          effectiveLength.projectID,
          .equivalentLength(.delete(id: effectiveLength.id))
        )
      )
    }

    var body: some HTML<HTMLTag.tr> {
      tr(.id(effectiveLength.id.idString)) {
        td {
          // Type
          Badge {
            span { effectiveLength.type.rawValue }
          }
          .attributes(.class("badge-info"), when: effectiveLength.type == .supply)
          .attributes(.class("badge-error"), when: effectiveLength.type == .return)

        }
        td { effectiveLength.name }
        td {
          // Lengths
          div(.class("grid grid-cols-1 gap-2")) {
            for length in effectiveLength.straightLengths {
              Number(length)
            }
          }
        }
        td {
          div(.class("grid grid-cols-3 gap-2 min-w-[220px]")) {
            for group in effectiveLength.groups {
              span { "\(group.group)-\(group.letter)" }
              div(.class("flex justify-center")) {
                Number(group.value)
              }
              div(.class("flex justify-end")) {
                Number(group.quantity)
              }
            }
          }

        }
        td {
          // Total
          // Row {
          div(.class("flex justify-end mx-auto space-x-4")) {
            Badge(number: effectiveLength.totalEquivalentLength, digits: 0)
              .attributes(.class("badge-primary badge-lg pt-2"))

            // Buttons
            div(.class("flex justify-end -mt-2")) {
              div(.class("join")) {
                TrashButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .hx.delete(route: deleteRoute),
                    .hx.confirm("Are you sure?"),
                    .hx.target("#\(effectiveLength.id.idString)"),
                    .hx.swap(.outerHTML)
                  )
                  .tooltip("Delete", position: .bottom)

                EditButton()
                  .attributes(
                    .class("join-item btn-ghost"),
                    .showModal(id: EffectiveLengthForm.id(effectiveLength))
                  )
                  .tooltip("Edit", position: .bottom)
              }
            }
          }

          EffectiveLengthForm(effectiveLength: effectiveLength)
        }
      }
    }
  }

}
