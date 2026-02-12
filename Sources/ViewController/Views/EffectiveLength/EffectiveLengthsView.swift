import Elementary
import ElementaryHTMX
import ManualDCore
import Styleguide

struct EffectiveLengthsView: HTML, Sendable {

  @Environment(ProjectViewValue.$projectID) var projectID

  let effectiveLengths: [EquivalentLength]

  var supplies: [EquivalentLength] {
    effectiveLengths.filter({ $0.type == .supply })
      .sorted { $0.totalEquivalentLength > $1.totalEquivalentLength }
  }

  var returns: [EquivalentLength] {
    effectiveLengths.filter({ $0.type == .return })
      .sorted { $0.totalEquivalentLength > $1.totalEquivalentLength }
  }

  var body: some HTML {
    div(.class("space-y-4")) {
      PageTitleRow {
        PageTitle { "Equivalent Lengths" }
        PlusButton()
          .attributes(
            .class("btn-primary"),
            .showModal(id: EffectiveLengthForm.id(nil))
          )
          .tooltip("Add equivalent length")
      }
      .attributes(.class("pb-6"))

      EffectiveLengthForm(projectID: projectID, dismiss: true)

      EffectiveLengthsTable(effectiveLengths: effectiveLengths)

    }
  }
}
