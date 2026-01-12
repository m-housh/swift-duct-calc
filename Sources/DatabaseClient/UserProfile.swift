import Dependencies
import DependenciesMacros
import Fluent
import ManualDCore
import Vapor

extension DatabaseClient {
  @DependencyClient
  public struct UserProfile: Sendable {
    public var create: @Sendable (User.Profile.Create) async throws -> User.Profile
    public var delete: @Sendable (User.Profile.ID) async throws -> Void
    public var get: @Sendable (User.Profile.ID) async throws -> User.Profile?
    public var update: @Sendable (User.Profile.ID, User.Profile.Update) async throws -> User.Profile
  }
}

extension DatabaseClient.UserProfile: TestDependencyKey {

  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { profile in
        try profile.validate()
        let model = profile.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await UserProfileModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      get: { id in
        try await UserProfileModel.find(id, on: database)
          .map { try $0.toDTO() }
      },
      update: { id, updates in
        guard let model = try await UserProfileModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try updates.validate()
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.save(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension User.Profile.Create {

  func validate() throws(ValidationError) {
    guard !firstName.isEmpty else {
      throw ValidationError("User first name should not be empty.")
    }
    guard !lastName.isEmpty else {
      throw ValidationError("User last name should not be empty.")
    }
  }

  func toModel() -> UserProfileModel {
    .init(userID: userID, firstName: firstName, lastName: lastName, theme: theme)
  }
}

extension User.Profile.Update {

  func validate() throws(ValidationError) {
    if let firstName {
      guard !firstName.isEmpty else {
        throw ValidationError("User first name should not be empty.")
      }
    }
    if let lastName {
      guard !lastName.isEmpty else {
        throw ValidationError("User last name should not be empty.")
      }
    }
  }
}

extension User.Profile {

  struct Migrate: AsyncMigration {
    let name = "Create UserProfile"

    func prepare(on database: any Database) async throws {
      try await database.schema(UserProfileModel.schema)
        .id()
        .field("firstName", .string, .required)
        .field("lastName", .string, .required)
        .field("theme", .string)
        .field("userID", .uuid, .references(UserModel.schema, "id", onDelete: .cascade))
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .unique(on: "userID")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(UserProfileModel.schema).delete()
    }
  }
}

final class UserProfileModel: Model, @unchecked Sendable {

  static let schema = "user_profile"

  @ID(key: .id)
  var id: UUID?

  @Parent(key: "userID")
  var user: UserModel

  @Field(key: "firstName")
  var firstName: String

  @Field(key: "lastName")
  var lastName: String

  @Field(key: "theme")
  var theme: String?

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    userID: User.ID,
    firstName: String,
    lastName: String,
    theme: Theme? = nil
  ) {
    self.id = id
    $user.id = userID
    self.firstName = firstName
    self.lastName = lastName
    self.theme = theme?.rawValue
  }

  func toDTO() throws -> User.Profile {
    try .init(
      id: requireID(),
      userID: $user.id,
      firstName: firstName,
      lastName: lastName,
      theme: self.theme.flatMap(Theme.init),
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func applyUpdates(_ updates: User.Profile.Update) {
    if let firstName = updates.firstName, firstName != self.firstName {
      self.firstName = firstName
    }
    if let lastName = updates.lastName, lastName != self.lastName {
      self.lastName = lastName
    }
    if let theme = updates.theme, theme.rawValue != self.theme {
      self.theme = theme.rawValue
    }
  }

}
