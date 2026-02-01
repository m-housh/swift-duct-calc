import Dependencies
import DependenciesMacros
import Fluent
import Foundation
import ManualDCore
import Vapor

extension DatabaseClient.Users: TestDependencyKey {
  public static let testValue = Self()

  public static func live(database: any Database) -> Self {
    .init(
      create: { request in
        try request.validate()
        let model = try request.toModel()
        try await model.save(on: database)
        return try model.toDTO()
      },
      delete: { id in
        guard let model = try await UserModel.find(id, on: database) else {
          throw NotFoundError()
        }
        try await model.delete(on: database)
      },
      get: { id in
        try await UserModel.find(id, on: database).map { try $0.toDTO() }
      },
      login: { request in
        guard
          let user = try await UserModel.query(on: database)
            .with(\.$token)
            .filter(\UserModel.$email == request.email)
            .first()
        else {
          throw NotFoundError()
        }

        // Verify the password matches the user's hashed password.
        guard try user.verifyPassword(request.password) else {
          throw Abort(.unauthorized)
        }

        let token: User.Token

        // Check if there's a user token
        if let userToken = user.token {
          token = try userToken.toDTO()
        } else {
          // generate a new token
          let tokenModel = try user.generateToken()
          try await tokenModel.save(on: database)
          token = try tokenModel.toDTO()
        }

        return token

      },
      logout: { tokenID in
        guard let token = try await UserTokenModel.find(tokenID, on: database) else { return }
        try await token.delete(on: database)
      }
      // ,
      // token: { id in
      // }

    )
  }
}

extension User {
  struct Migrate: AsyncMigration {
    let name = "CreateUser"

    func prepare(on database: any Database) async throws {
      try await database.schema(UserModel.schema)
        .id()
        .field("email", .string, .required)
        .field("password_hash", .string, .required)
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .unique(on: "email")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(UserModel.schema).delete()
    }
  }
}

extension User.Token {
  struct Migrate: AsyncMigration {
    let name = "CreateUserToken"

    func prepare(on database: any Database) async throws {
      try await database.schema(UserTokenModel.schema)
        .id()
        .field("value", .string, .required)
        .field("user_id", .uuid, .required, .references(UserModel.schema, "id"))
        .field("createdAt", .datetime)
        .field("updatedAt", .datetime)
        .unique(on: "value")
        .create()
    }

    func revert(on database: any Database) async throws {
      try await database.schema(UserTokenModel.schema).delete()
    }
  }
}

extension User {

  static func hashPassword(_ password: String) throws -> String {
    try Bcrypt.hash(password, cost: 12)
  }

}

extension User.Create {

  func toModel() throws -> UserModel {
    return try .init(email: email, passwordHash: User.hashPassword(password))
  }
}

final class UserModel: Model, @unchecked Sendable {

  static let schema = "user"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "email")
  var email: String

  @Field(key: "password_hash")
  var passwordHash: String

  @Timestamp(key: "createdAt", on: .create, format: .iso8601)
  var createdAt: Date?

  @Timestamp(key: "updatedAt", on: .update, format: .iso8601)
  var updatedAt: Date?

  @OptionalChild(for: \.$user)
  var token: UserTokenModel?

  init() {}

  init(
    id: UUID? = nil,
    email: String,
    passwordHash: String
  ) {
    self.id = id
    self.email = email
    self.passwordHash = passwordHash
  }

  func toDTO() throws -> User {
    try .init(
      id: requireID(),
      email: email,
      createdAt: createdAt!,
      updatedAt: updatedAt!
    )
  }

  func generateToken() throws -> UserTokenModel {
    try .init(
      value: [UInt8].random(count: 16).base64,
      userID: requireID()
    )
  }

  func verifyPassword(_ password: String) throws -> Bool {
    try Bcrypt.verify(password, created: passwordHash)
  }
}

final class UserTokenModel: Model, Codable, @unchecked Sendable {

  static let schema = "user_token"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "value")
  var value: String

  @Parent(key: "user_id")
  var user: UserModel

  init() {}

  init(id: UUID? = nil, value: String, userID: UserModel.IDValue) {
    self.id = id
    self.value = value
    $user.id = userID
  }

  func toDTO() throws -> User.Token {
    try .init(id: requireID(), userID: $user.id, value: value)
  }

}

// MARK: - Authentication

extension User: Authenticatable {}
extension User: SessionAuthenticatable {
  public var sessionID: String { email }
}

public struct UserPasswordAuthenticator: AsyncBasicAuthenticator {
  public typealias User = ManualDCore.User

  public init() {}

  public func authenticate(basic: BasicAuthorization, for request: Request) async throws {
    guard
      let user = try await UserModel.query(on: request.db)
        .filter(\UserModel.$email == basic.username)
        .first(),
      try user.verifyPassword(basic.password)
    else {
      throw Abort(.unauthorized)
    }
    try request.auth.login(user.toDTO())
  }
}

public struct UserTokenAuthenticator: AsyncBearerAuthenticator {
  public typealias User = ManualDCore.User

  public init() {}

  public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
    guard
      let token = try await UserTokenModel.query(on: request.db)
        .filter(\UserTokenModel.$value == bearer.token)
        .with(\UserTokenModel.$user)
        .first()
    else {
      throw Abort(.unauthorized)
    }
    try request.auth.login(token.user.toDTO())
  }
}

public struct UserSessionAuthenticator: AsyncSessionAuthenticator {
  public typealias User = ManualDCore.User

  public init() {}

  public func authenticate(sessionID: User.SessionID, for request: Request) async throws {
    guard
      let user = try await UserModel.query(on: request.db)
        .filter(\UserModel.$email == sessionID)
        .first()
    else {
      throw Abort(.unauthorized)
    }
    try request.auth.login(user.toDTO())
  }
}
