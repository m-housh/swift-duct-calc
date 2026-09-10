import Elementary
import ManualDCore
import Styleguide

struct UserView: HTML, Sendable {
  let user: User
  let profile: User.Profile?

  var body: some HTML {
    div {
      Navbar()

      div(.class("p-4")) {
        a(.class("btn btn-secondary mb-4"), .href("/path-templates")) { "Path templates" }
        Row {
          h1(.class("text-2xl font-bold")) { "Account" }
          EditButton(accessibilityLabel: "Edit profile")
            .attributes(.showModal(id: UserProfileForm.id(profile)))
        }

        if let profile {
          table(.class("table details-table table-zebra border rounded-lg")) {
            tr {
              th(.init(name: "scope", value: "row")) { Label("Name") }
              td { "\(profile.firstName) \(profile.lastName)" }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("Company") }
              td { profile.companyName }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("Street Address") }
              td { profile.streetAddress }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("City") }
              td { profile.city }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("State") }
              td { profile.state }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("Zip Code") }
              td { profile.zipCode }
            }
            tr {
              th(.init(name: "scope", value: "row")) { Label("Theme") }
              td { profile.theme?.rawValue ?? "" }
            }

          }
        }
        UserProfileForm(userID: user.id, profile: profile, dismiss: true)
      }
    }
  }
}
