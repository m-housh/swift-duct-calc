import CSVParser
import ManualDCore
import Testing

struct FittingCSVParserTests {
  @Test func headersQuotingWhitespaceAndPhysicalLines() {
    let csv =
      "\u{feff}\r\n quantity , code , length_ft \r\n,\" 4ag \",30.5\r\n\r\n2,\"8A-\n smooth\",12.25\r\n1,\"a,\"\"b\"\"\",9"
    let result = FittingCSVParser.parse(csv)
    #expect(result.issues.isEmpty)
    #expect(result.rows.map(\.line) == [3, 5, 7])
    #expect(result.rows.map(\.code) == ["4ag", "8A-\n smooth", "a,\"b\""])
    #expect(result.rows.map(\.feet) == [30.5, 12.25, 9])
    #expect(result.rows.map(\.quantity) == [1, 2, 1])
  }

  @Test func optionalQuantitiesAndRepeatedCodes() {
    let result = FittingCSVParser.parse("code,length_ft\n8A,1\n1A,2\n8A,3\n")
    #expect(result.issues.isEmpty)
    #expect(result.rows.map(\.code) == ["8A", "1A", "8A"])
    #expect(result.rows.map(\.quantity) == [1, 1, 1])
  }

  @Test(arguments: [
    "", "1A,3", "code,code,length_ft\n1A,1A,3", "code,length_ft,extra\n1A,3,x", "code,length_ft",
  ])
  func rejectsMissingInvalidOrEmptyHeaders(_ csv: String) {
    #expect(!FittingCSVParser.parse(csv).issues.isEmpty)
  }

  @Test(arguments: ["1A,\"3", "1\"A,3", "\"1A\"x,3", "1A,3,2", "1A"])
  func malformedCSVIsNotSkipped(_ row: String) {
    let result = FittingCSVParser.parse("code,length_ft\n" + row)
    #expect(result.rows.isEmpty)
    #expect(result.issues.first?.line == 2)
    #expect(result.issues.first?.field == "CSV")
  }

  @Test(arguments: ["nan", "inf", "-1", "0", "", "1e999", "\"1,5\""])
  func invalidLengths(_ value: String) {
    let result = FittingCSVParser.parse("code,length_ft\n1A,\(value)")
    #expect(result.rows.isEmpty)
    #expect(result.issues.first?.field == "length_ft")
  }

  @Test(arguments: ["0", "-1", "1.5", "1e2", "+2", "1000001", "999999999999999999999"])
  func invalidQuantities(_ value: String) {
    let result = FittingCSVParser.parse("code,length_ft,quantity\n1A,3,\(value)")
    #expect(result.rows.isEmpty)
    #expect(result.issues.first?.field == "quantity")
  }

  @Test func reportsAllInvalidFieldsAndKeepsValidRowsForReview() {
    let result = FittingCSVParser.parse("code,length_ft,quantity\n,,0\n1A,2,1\n")
    #expect(result.issues.map(\.field) == ["code", "length_ft", "quantity"])
    #expect(result.rows.map(\.line) == [3])
  }

  @Test func limitsAndOverflow() {
    #expect(
      FittingCSVParser.parse(String(repeating: "a", count: 65_537)).issues.first?.field == "file")
    #expect(
      FittingCSVParser.parse("code,length_ft\n" + String(repeating: "1A,1\n", count: 500)).rows
        .count == 500)
    #expect(
      FittingCSVParser.parse("code,length_ft\n" + String(repeating: "1A,1\n", count: 501)).issues
        .first?.field == "file")
    #expect(
      FittingCSVParser.parse("code,length_ft,quantity\n1A,1e308,100").issues.first?.field
        == "length_ft")
  }
}
