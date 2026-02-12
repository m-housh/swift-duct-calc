import Dependencies
import Foundation
import ManualDCore
import Testing
import Vapor

@testable import DatabaseClient

@Suite
struct UserDatabaseTests {

  @Test
  func happyPaths() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users

      let user = try await users.create(
        .init(email: "testy@example.com", password: "super-secret", confirmPassword: "super-secret")
      )

      #expect(user.email == "testy@example.com")

      // Test login the user in
      let token = try await users.login(
        .init(email: user.email, password: "super-secret")
      )
      #expect(token.userID == user.id)
      // Test the same token is returned.
      let token2 = try await users.login(
        .init(email: user.email, password: "super-secret")
      )
      #expect(token.id == token2.id)
      // Test logging out
      try await users.logout(token.id)

      try await users.delete(user.id)

      let shouldBeNilUser = try await users.get(user.id)
      #expect(shouldBeNilUser == nil)
    }
  }

  @Test
  func deleteFailsWithInvalidUserID() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users
      await #expect(throws: NotFoundError.self) {
        try await users.delete(UUID(0))
      }
    }
  }

  @Test
  func logoutIgnoresUnfoundTokenID() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users
      try await users.logout(UUID(0))
    }
  }

  @Test
  func loginFails() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users

      await #expect(throws: NotFoundError.self) {
        try await users.login(
          .init(email: "foo@example.com", password: "super-secret")
        )

      }

      let user = try await users.create(
        .init(email: "testy@example.com", password: "super-secret", confirmPassword: "super-secret")
      )

      // Ensure can not login with invalid password
      await #expect(throws: Abort.self) {
        try await users.login(
          .init(email: user.email, password: "wrong-password")
        )
      }
    }
  }

  @Test
  func userProfileHappyPath() async throws {
    try await withTestUser { user in
      @Dependency(\.database.userProfiles) var profiles
      let profile = try await profiles.create(
        .init(
          userID: user.id,
          firstName: "Testy",
          lastName: "McTestface",
          companyName: "Acme Co.",
          streetAddress: "12345 Sesame St",
          city: "Nowhere",
          state: "FL",
          zipCode: "55555"
        )
      )

      let fetched = try await profiles.fetch(user.id)
      #expect(fetched == profile)

      let got = try await profiles.get(profile.id)
      #expect(got == profile)

      let updated = try await profiles.update(profile.id, .init(firstName: "Updated"))
      #expect(updated.firstName == "Updated")
      #expect(updated.id == profile.id)

      try await profiles.delete(profile.id)
    }
  }

  @Test
  func testUserProfileFails() async throws {
    try await withDatabase {
      @Dependency(\.database.userProfiles) var profiles
      await #expect(throws: NotFoundError.self) {
        try await profiles.delete(UUID(0))
      }
      await #expect(throws: NotFoundError.self) {
        try await profiles.update(UUID(0), .init(firstName: "Foo"))
      }
    }
  }

  @Test(
    arguments: [
      UserProfileModel(
        userID: UUID(0), firstName: "", lastName: "McTestface", companyName: "Acme Co.",
        streetAddress: "1234 Sesame St", city: "Nowhere", state: "CA", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "", companyName: "Acme Co.",
        streetAddress: "1234 Sesame St", city: "Nowhere", state: "CA", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "McTestface", companyName: "",
        streetAddress: "1234 Sesame St", city: "Nowhere", state: "CA", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "McTestface", companyName: "Acme Co.",
        streetAddress: "", city: "Nowhere", state: "CA", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "McTestface", companyName: "Acme Co.",
        streetAddress: "1234 Sesame St", city: "", state: "CA", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "McTestface", companyName: "Acme Co.",
        streetAddress: "1234 Sesame St", city: "Nowhere", state: "", zipCode: "55555"
      ),
      UserProfileModel(
        userID: UUID(0), firstName: "Testy", lastName: "McTestface", companyName: "Acme Co.",
        streetAddress: "1234 Sesame St", city: "Nowhere", state: "CA", zipCode: ""
      ),
    ]
  )
  func profileValidations(model: UserProfileModel) {
    var errors = [String]()
    #expect(throws: (any Error).self) {
      do {
        try model.validate()
      } catch {
        // Just checking to make sure I'm not testing the same error over and over /
        // making sure I've reset to good values / only testing one property at a time.
        #expect(!errors.contains("\(error)"))
        errors.append("\(error)")
        throw error
      }
    }
  }

  @Test(
    arguments: [
      User.Create(email: "", password: "super-secret", confirmPassword: "super-secret"),
      User.Create(email: "testy@example.com", password: "", confirmPassword: "super-secret"),
      User.Create(email: "testy@example.com", password: "super-secret", confirmPassword: ""),
      User.Create(email: "testy@example.com", password: "super", confirmPassword: "super"),
    ]
  )
  func userValidations(model: User.Create) {
    #expect(throws: (any Error).self) {
      try model.validate()
    }
  }
}
