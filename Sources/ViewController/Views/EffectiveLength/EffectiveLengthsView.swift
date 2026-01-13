import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let effectiveLengths: [EffectiveLength]

  var supplies: [EffectiveLength] {
    effectiveLengths.filter({ $0.type == .supply })
      .sorted { $0.totalEquivalentLength > $1.totalEquivalentLength }
  }

  var returns: [EffectiveLength] {
    effectiveLengths.filter({ $0.type == .return })
      .sorted { $0.totalEquivalentLength > $1.totalEquivalentLength }
  }

  var body: some HTML {
    div(.class("space-y-4")) {
      Row {
        PageTitle { "Equivalent Lengths" }
        PlusButton()
          .attributes(
            .class("btn-ghost"),
            .showModal(id: EffectiveLengthForm.id(nil))
          )
      }
      .attributes(.class("pb-6"))

      EffectiveLengthForm(projectID: projectID, dismiss: true)

      div {
        h2(.class("text-xl font-bold pb-4")) { "Supplies" }
          .attributes(.class("hidden"), when: supplies.count == 0)

        div(.class("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4")) {
          for row in supplies {
            EffectiveLengthView(effectiveLength: row)
          }
        }
      }

      div {
        h2(.class("text-xl font-bold pb-4")) { "Returns" }
          .attributes(.class("hidden"), when: returns.count == 0)
        div(.class("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 space-x-4 space-y-4")) {
          for row in returns {
            EffectiveLengthView(effectiveLength: row)
          }
        }
      }

    }
  }

  private struct EffectiveLengthView: HTML, Sendable {

    let effectiveLength: EffectiveLength

    var straightLengthsTotal: Int {
      effectiveLength.straightLengths
        .reduce(into: 0) { $0 += $1 }
    }

    var groupsTotal: Double {
      effectiveLength.groups.totalEquivalentLength
    }

    var id: String {
      return "effectiveLenghtCard_\(effectiveLength.id.uuidString.replacing("-", with: ""))"
    }

    var body: some HTML<HTMLTag.div> {
      div(
        .class("card h-full bg-base-100 shadow-sm border rounded-lg"),
        .id(id)
      ) {
        div(.class("card-body text-lg")) {
          Row {
            h2 { effectiveLength.name }
            div(
              .class("space-x-4")
            ) {
              span(.class("text-primary text-sm italic")) {
                "Total"
              }

              Number(self.effectiveLength.totalEquivalentLength, digits: 0)
                .attributes(.class("badge badge-outline badge-primary text-lg"))
            }
          }
          .attributes(.class("card-title pb-6"))

          Row {
            Label { "Straight Lengths" }

            ul {
              for length in effectiveLength.straightLengths {
                li {
                  Number(length)
                }
              }
            }
          }
          .attributes(.class("pb-6"))

          Row {
            span { "Groups" }
            span { "Equivalent Length" }
            span { "Quantity" }
          }
          .attributes(.class("label font-bold border-b border-label"))

          for group in effectiveLength.groups {
            Row {
              span { "\(group.group)-\(group.letter)" }
              Number(group.value)
              Number(group.quantity)
            }
          }

          div(.class("card-actions justify-end pt-6 space-y-4 mt-auto")) {
            div(.class("join")) {
              TrashButton()
                .attributes(
                  .class("join-item btn-ghost"),
                  .hx.delete(
                    route: .project(
                      .detail(
                        effectiveLength.projectID,
                        .equivalentLength(.delete(id: effectiveLength.id))
                      )
                    )
                  ),
                  .hx.confirm("Are you sure?"),
                  .hx.target("#\(id)"),
                  .hx.swap(.outerHTML)
                )
              EditButton()
                .attributes(
                  .class("join-item btn-ghost"),
                  .showModal(id: EffectiveLengthForm.id(effectiveLength))
                )
            }
          }

          EffectiveLengthForm(effectiveLength: effectiveLength)
        }
      }
    }
  }
}
