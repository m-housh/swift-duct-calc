import Dependencies
import Elementary
import Foundation
import ManualDCore

struct TestPage: HTML, Sendable {
  var body: some HTML {
    UserProfileForm(userID: UUID(0), profile: nil, dismiss: false)
  }
}
