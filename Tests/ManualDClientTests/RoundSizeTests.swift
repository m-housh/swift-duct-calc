import ManualDCore
import Testing

@testable import ManualDClient

struct RoundSizeTests {
  @Test(arguments: [4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22, 24])
  func keepsExactStandardSizes(size: Int) throws {
    #expect(try roundSize(Double(size)) == size)
  }

  @Test(arguments: [
    (0.1, 4), (3.99, 4), (4.01, 5), (5.01, 6), (6.01, 7), (7.01, 8),
    (8.01, 9), (9.01, 10), (10.01, 12), (12.01, 14), (14.01, 16),
    (16.01, 18), (18.01, 20), (20.01, 22), (21, 22), (21.99, 22),
    (22.01, 24), (23.99, 24),
  ])
  func roundsUpToNextStandardSize(size: Double, expected: Int) throws {
    #expect(try roundSize(size) == expected)
  }

  @Test(arguments: [0, -1, 24.01, Double.infinity, -Double.infinity, Double.nan])
  func rejectsInvalidSizes(size: Double) {
    #expect(throws: ManualDError.self) {
      try roundSize(size)
    }
  }
}
