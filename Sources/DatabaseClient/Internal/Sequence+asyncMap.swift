import Foundation

extension Sequence {

  // Taken from: https://forums.swift.org/t/are-there-any-kind-of-asyncmap-method-for-a-normal-sequence/77354/7
  func asyncMap<Result: Sendable>(
    _ transform: @escaping @Sendable (Element) async throws -> Result
  ) async rethrows -> [Result] where Element: Sendable {
    try await withThrowingTaskGroup(of: (Int, Result).self) { group in

      var i = 0
      var iterator = self.makeIterator()
      var results = [Result?]()
      results.reserveCapacity(underestimatedCount)

      func submitTask() throws {
        try Task.checkCancellation()
        if let element = iterator.next() {
          results.append(nil)
          group.addTask { [i] in try await (i, transform(element)) }
          i += 1
        }

      }

      // Add initial tasks
      for _ in 0..<ProcessInfo.processInfo.processorCount {
        try submitTask()
      }

      // Submit more tasks as results complete
      while let (index, result) = try await group.next() {
        results[index] = result
        try submitTask()
      }

      return results.compactMap { $0 }

    }
  }
}
