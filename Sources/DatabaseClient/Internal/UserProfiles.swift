import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import Validations

extension DatabaseClient.UserProfiles: TestDependencyKey {

  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { profile in
        let model = profile.toModel()
        try await model.validateAndSave(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await UserProfileModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      fetch: { userID in
        try await UserProfileModel.query(on: database)
          .with(\.$user)
          .filter(\.$user.$id == userID)
          .first()
          .map { try $0.toDTO() }
      },
      get: { id in
        try await UserProfileModel.find(id, on: database)
          .map { try $0.toDTO() }
      },
      update: { id, updates in
        guard let model = try await UserProfileModel.find(id, on: database) else {
          throw NotFoundError()
        }
        model.applyUpdates(updates)
        if model.hasChanges {
          try await model.validateAndSave(on: database)
        }
        return try model.toDTO()
      }
    )
  }
}

extension User.Profile.Create {

  func toModel() -> UserProfileModel {
    .init(
      userID: userID,
      firstName: firstName,
      lastName: lastName,
      companyName: companyName,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
      theme: theme
    )
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
        .field("companyName", .string, .required)
        .field("streetAddress", .string, .required)
        .field("city", .string, .required)
        .field("state", .string, .required)
        .field("zipCode", .string, .required)
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

  @Field(key: "companyName")
  var companyName: String

  @Field(key: "streetAddress")
  var streetAddress: String

  @Field(key: "city")
  var city: String

  @Field(key: "state")
  var state: String

  @Field(key: "zipCode")
  var zipCode: String

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
    companyName: String,
    streetAddress: String,
    city: String,
    state: String,
    zipCode: String,
    theme: Theme? = nil
  ) {
    self.id = id
    $user.id = userID
    self.firstName = firstName
    self.lastName = lastName
    self.companyName = companyName
    self.streetAddress = streetAddress
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.theme = theme?.rawValue
  }

  func toDTO() throws -> User.Profile {
    try .init(
      id: requireID(),
      userID: $user.id,
      firstName: firstName,
      lastName: lastName,
      companyName: companyName,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
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
    if let companyName = updates.companyName, companyName != self.companyName {
      self.companyName = companyName
    }
    if let streetAddress = updates.streetAddress, streetAddress != self.streetAddress {
      self.streetAddress = streetAddress
    }
    if let city = updates.city, city != self.city {
      self.city = city
    }
    if let state = updates.state, state != self.state {
      self.state = state
    }
    if let zipCode = updates.zipCode, zipCode != self.zipCode {
      self.zipCode = zipCode
    }
    if let theme = updates.theme, theme.rawValue != self.theme {
      self.theme = theme.rawValue
    }
  }

}

extension UserProfileModel: Validatable {

  var body: some Validation<UserProfileModel> {
    Validator.accumulating {
      Validator.validate(\.firstName, with: .notEmpty())
        .errorLabel("First Name", inline: true)

      Validator.validate(\.lastName, with: .notEmpty())
        .errorLabel("Last Name", inline: true)

      Validator.validate(\.companyName, with: .notEmpty())
        .errorLabel("Company", inline: true)

      Validator.validate(\.streetAddress, with: .notEmpty())
        .errorLabel("Address", inline: true)

      Validator.validate(\.city, with: .notEmpty())
        .errorLabel("City", inline: true)

      Validator.validate(\.state, with: .notEmpty())
        .errorLabel("State", inline: true)

      Validator.validate(\.zipCode, with: .notEmpty())
        .errorLabel("Zip", inline: true)
    }
  }
}
