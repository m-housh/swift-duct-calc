import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

// TODO: Group into grids of supply / return.

struct EffectiveLengthsView: HTML, Sendable {

  let projectID: Project.ID
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
    div(
      .class("m-4 space-y-4")
    ) {
      Row {
        h1(.class("text-2xl font-bold")) { "Equivalent Lengths" }
        PlusButton()
          .attributes(.showModal(id: EffectiveLengthForm.id(nil)))
      }
      .attributes(.class("pb-6"))

      EffectiveLengthForm(projectID: projectID, dismiss: true)

      div {
        h2(.class("text-xl font-bold pb-4")) { "Supplies" }
        div(.class("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4")) {
          for (n, row) in supplies.enumerated() {
            EffectiveLengthView(effectiveLength: row)
              .attributes(.class(n == 0 ? "border-primary" : "border-gray-200"))
          }
        }
      }

      div {
        h2(.class("text-xl font-bold pb-4")) { "Returns" }
        div(.class("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 space-x-4 space-y-4")) {
          for (n, row) in returns.enumerated() {
            EffectiveLengthView(effectiveLength: row)
              .attributes(.class(n == 0 ? "border-secondary" : "border-gray-200"))
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
        div(.class("card-body")) {
          Row {
            h2 { effectiveLength.name }
            div(
              .class("space-x-4")
            ) {
              span(.class("text-sm italic")) {
                "Total"
              }
              .attributes(.class("text-primary"), when: effectiveLength.type == .supply)
              .attributes(.class("text-secondary"), when: effectiveLength.type == .return)

              Number(self.effectiveLength.totalEquivalentLength, digits: 0)
                .attributes(.class("badge badge-outline text-lg"))
                .attributes(
                  .class("badge-primary"), when: effectiveLength.type == .supply
                )
                .attributes(
                  .class("badge-secondary"), when: effectiveLength.type == .return
                )
            }
          }
          .attributes(.class("card-title pb-6"))

          Label("Straight Lengths")

          for length in effectiveLength.straightLengths {
            div(.class("flex justify-end")) {
              Number(length)
            }
          }

          Row {
            Label("Groups")
            Label("Equivalent Length")
            Label("Quantity")
          }
          .attributes(.class("border-b border-gray-200"))

          for group in effectiveLength.groups {
            Row {
              span { "\(group.group)-\(group.letter)" }
              Number(group.value)
              Number(group.quantity)
            }
          }

          div(.class("card-actions justify-end pt-6 space-y-4 mt-auto")) {
            // TODO: Delete.
            TrashButton()
              .attributes(
                .hx.delete(
                  route: .project(
                    .detail(
                      effectiveLength.projectID, .equivalentLength(.delete(id: effectiveLength.id)))
                  )),
                .hx.confirm("Are you sure?"),
                .hx.target("#\(id)"),
                .hx.swap(.outerHTML)
              )
            EditButton()
              .attributes(.showModal(id: EffectiveLengthForm.id(effectiveLength)))
          }

          EffectiveLengthForm(effectiveLength: effectiveLength)
        }
      }
    }
  }
}
