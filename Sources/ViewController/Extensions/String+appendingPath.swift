import Foundation

extension String {

  func appendingPath(_ string: String) -> Self {
    guard string.starts(with: "/") else {
      return self.appending("/\(string)")
    }
    return self.appending(string)
  }

  func appendingPath(_ id: UUID?) -> Self {
    guard let id else { return self }
    return appendingPath(id.uuidString)
  }

  func appendingPath(_ id: UUID) -> Self {
    return appendingPath(id.uuidString)
  }
}
