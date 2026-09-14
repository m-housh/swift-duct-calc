import Dependencies
import Foundation
import HTMLSnapshotTesting
import ManualDCore
import SnapshotTesting
import Testing

@testable import ViewController

@Suite(.snapshots(record: .failed))
struct AccountPageTests {
  private var profile: User.Profile {
    .init(
      id: UUID(1), userID: UUID(0), firstName: "Alex", lastName: "Morgan",
      companyName: "Morgan Heating & Air", streetAddress: "123 Main Street",
      city: "Monroe", state: "OH", zipCode: "45050", theme: .dark,
      createdAt: .init(timeIntervalSince1970: 0), updatedAt: .init(timeIntervalSince1970: 0))
  }

  @Test func profileForms() {
    assertSnapshot(
      of: UserProfileForm(userID: UUID(0), profile: profile), as: .html, named: "existing")
    assertSnapshot(of: UserProfileForm(userID: UUID(0)), as: .html, named: "missing")
    assertSnapshot(of: UserProfileForm(userID: UUID(0), signup: true), as: .html, named: "signup")

    let existing = UserProfileForm(userID: UUID(0), profile: profile).render()
    #expect(existing.contains("hx-patch=\"/profile/\(profile.id)\""))
    #expect(!existing.contains("<dialog"))
    let missing = UserProfileForm(userID: UUID(0)).render()
    #expect(missing.contains("hx-post=\"/profile\""))
    let signup = UserProfileForm(userID: UUID(0), signup: true).render()
    #expect(signup.contains("hx-post=\"/signup/profile\""))
    #expect(signup.contains("hx-push-url=\"/projects\""))
    #expect(!signup.contains("Account sections"))
  }

  @Test func accountTemplates() throws {
    assertSnapshot(of: PathTemplatesView(templates: [], projectID: nil), as: .html, named: "empty")
    let configuration = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      PathTemplate.defaultConfigurations()[0]
    }
    let workspace = try PathTemplateWorkspace(
      data: .init(
        mode: "editor", configuration: configuration, template: nil,
        definitions: [], projectID: nil, path: nil, saveURL: "/path-templates",
        backURL: "/path-templates"))
    assertSnapshot(of: workspace, as: .html, named: "editor")
    #expect(workspace.render().contains("Account sections"))
    let projectTemplates = PathTemplatesView(templates: [], projectID: UUID(0), choosing: true)
      .render()
    #expect(!projectTemplates.contains("Account sections"))
    #expect(projectTemplates.contains("Back to project"))
  }
}
