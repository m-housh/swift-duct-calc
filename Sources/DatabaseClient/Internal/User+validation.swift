import ManualDCore
import Validations

// Declaring this in seperate file because some Vapor imports
// have same name's and this was easiest solution.
extension User.Create: Validatable {
  public var body: some Validation<Self> {
    Validator.accumulating {
      Validator.validate(\.email, with: .email())
        .errorLabel("Email", inline: true)

      Validator.validate(\.password.count, with: .greaterThanOrEquals(8))
        .errorLabel("Password Count", inline: true)

      Validator.validate(\.confirmPassword, with: .equals(password))
        .mapError(ValidationError("Confirm password does not match."))
        .errorLabel("Confirm Password", inline: true)
    }
  }
}
