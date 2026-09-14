import ManualDCore
import Validations

func validationFields(_ error: any Error) -> [PresentationError.Field]? {
  guard let error = error as? ValidationError else { return nil }
  switch error {
  case .manyFailed(let errors, _):
    return errors.flatMap { error in
      validationFields(error)
        ?? [.init("", "Check the submitted values.")]
    }
  case .failed(let label, _):
    let name: String
    switch label {
    case .inline(let value), .notInline(let value): name = value
    }
    switch name {
    case "Static Pressure":
      return [
        .init(
          "staticPressure",
          "External static pressure must be greater than 0 and less than 1 in. w.c.")
      ]
    case "Heating CFM":
      return [.init("heatingCFM", "Heating airflow must be a positive whole number in CFM.")]
    case "Cooling CFM":
      return [.init("coolingCFM", "Cooling airflow must be a positive whole number in CFM.")]
    case "Component Pressure Loss":
      return [
        .init(
          "value", "Component pressure loss must be greater than 0 and no greater than 1 in. w.c.")
      ]
    case "Heating Load": return [.init("heatingLoad", "Heating load must be zero or greater.")]
    case "Cooling Load":
      return [
        .init(
          "",
          "Enter valid total and sensible cooling loads, with sensible load no greater than total load."
        )
      ]
    case "Register Count":
      return [
        .init(
          "registerCount",
          "Enter a whole register count. Use at least one register unless this room delegates airflow."
        )
      ]
    case "Sensible Heat Ratio":
      return [
        .init(
          "sensibleHeatRatio", "Sensible heat ratio must be greater than 0 and no greater than 1.")
      ]
    case "Email": return [.init("email", "Enter a valid email address.")]
    case "Password Count": return [.init("password", "Use a password with at least 8 characters.")]
    case "Confirm Password": return [.init("confirmPassword", "The passwords do not match.")]
    case "Height":
      return [.init("height", "Duct height must be a positive whole number of inches.")]
    case "Straight Lengths":
      return [.init("straightLengths", "Enter positive straight duct lengths in whole feet.")]
    case "Name": return [.init("name", "Enter a name.")]
    case "Address": return [.init("streetAddress", "Enter a street address.")]
    case "City": return [.init("city", "Enter a city.")]
    case "State": return [.init("state", "Enter a state.")]
    case "Zip": return [.init("zipCode", "Enter a ZIP code.")]
    case "First Name": return [.init("firstName", "Enter a first name.")]
    case "Last Name": return [.init("lastName", "Enter a last name.")]
    case "Company": return [.init("companyName", "Enter a company name.")]
    default:
      return [
        .init("", name.isEmpty ? "Check the submitted values." : "Check \(name.lowercased()).")
      ]
    }
  }
}
