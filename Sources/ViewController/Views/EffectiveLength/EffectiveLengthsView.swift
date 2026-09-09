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
        a(
          .href("/projects/\(projectID)/effective-lengths/editor"), .class("btn btn-primary"),
          .init(name: "aria-label", value: "Add equivalent length"), .title("Add equivalent length")
        ) {
          SVG(.circlePlus)
        }

      }
      .attributes(.class("pb-6"))

      a(.class("link"), .href(pathTemplatesURL(projectID))) { "Manage path templates" }

      EffectiveLengthsTable(effectiveLengths: effectiveLengths)

    }
  }
}
