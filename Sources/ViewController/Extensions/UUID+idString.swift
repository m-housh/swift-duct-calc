import Foundation

extension UUID {
  var idString: String {
    uuidString.replacing("-", with: "")
  }
}
