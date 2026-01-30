import DatabaseClient
import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import DatabaseClient

@Suite
struct UserDatabaseTests {

  @Test
  func createUser() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users

      let user = try await users.create(
        .init(email: "testy@example.com", password: "super-secret", confirmPassword: "super-secret")
      )

      #expect(user.email == "testy@example.com")

      // Test login the user in
      let token = try await users.login(
        .init(email: "testy@example.com", password: "super-secret")
      )
      // Test logging out
      try await users.logout(token.id)

      try await users.delete(user.id)

      let shouldBeNilUser = try await users.get(user.id)
      #expect(shouldBeNilUser == nil)

    }
  }

  @Test
  func createUserFails() async throws {
    try await withDatabase {
      @Dependency(\.database.users) var users

      await #expect(throws: ValidationError.self) {
        try await users.create(.init(email: "", password: "", confirmPassword: ""))
      }

      await #expect(throws: ValidationError.self) {
        try await users.create(.init(email: "testy@example.com", password: "", confirmPassword: ""))
      }

      await #expect(throws: ValidationError.self) {
        try await users.create(
          .init(email: "testy@example.com", password: "super-secret", confirmPassword: ""))
      }
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

}
