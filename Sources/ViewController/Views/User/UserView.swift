import Elementary
import ManualDCore

struct UserView: HTML, Sendable {
  let user: User
  let profile: User.Profile?

  var body: some HTML {
    AccountPage(selected: .profile) {
      header(.class("account-heading")) {
        h1 { "Profile" }
        p { "Your personal details, company address, and appearance." }
      }
      UserProfileForm(userID: user.id, profile: profile)
    }
  }
}
