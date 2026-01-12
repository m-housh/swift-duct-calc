import Elementary
import ManualDCore
import Styleguide

struct UserView: HTML, Sendable {
  let user: User
  let profile: User.Profile?

  var body: some HTML {
    div {
      Row {
        h1(.class("text-2xl font-bold")) { "Account" }
        EditButton()
          .attributes(.showModal(id: UserProfileForm.id(profile)))
      }

      if let profile {
        table(.class("table table-zebra")) {
          tr {
            td { Label("Name") }
            td { "\(profile.firstName) \(profile.lastName)" }
          }
          tr {
            td { Label("Company") }
            td { profile.companyName }
          }
          tr {
            td { Label("Street Address") }
            td { profile.streetAddress }
          }
          tr {
            td { Label("City") }
            td { profile.city }
          }
          tr {
            td { Label("State") }
            td { profile.state }
          }
          tr {
            td { Label("Zip Code") }
            td { profile.zipCode }
          }
          tr {
            td { Label("Theme") }
            td { profile.theme?.rawValue ?? "" }
          }

        }
      }
      UserProfileForm(userID: user.id, profile: profile, dismiss: true)
    }
  }
}
