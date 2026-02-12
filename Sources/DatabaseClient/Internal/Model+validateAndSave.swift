import Fluent
import Validations

extension Model where Self: Validations.Validatable {

  func validateAndSave(on database: any Database) async throws {
    try self.validate()
    try await self.save(on: database)
  }
}
