import Foundation
import Parsing
import Testing

@testable import PdfImportClient

struct ReportParsersTests {
  @Test(arguments: [
    "0", "0000", "1234", "1,234", "12,345,678", "0.833", "1,234.50", "123456.789",
    "123,456,789.012",
  ])
  func reportNumbers(raw: String) throws {
    #expect(try ReportNumber().parse(raw) == Double(raw.replacingOccurrences(of: ",", with: "")))
  }

  @Test(arguments: [
    "", "-1", "+1", "1e3", "nan", "inf", ".5", "1.", "1,23", "1234,567", "1,,234",
    "1,2345", "1,234,56", "1,234.", "1,234.5.6", "12 BTU/h", " 12", "12 ",
    String(repeating: "9", count: 400),
  ])
  func rejectsInvalidNumbers(raw: String) {
    #expect(throws: (any Error).self) { try ReportNumber().parse(raw) }
  }

  @Test
  func loadLineWhitespaceAndUnits() throws {
    let loads = try RoomLoads().parse(
      "Heating Load:\t1,234.5 BTU/h\u{00A0}Cooling Load: 678 BTU/h")
    #expect(loads.heating == 1234.5)
    #expect(loads.cooling == 678)
    for line in [
      "Heating Load: 1,234 BTU/h Cooling Load: 1,23 BTU/h",
      "Heating Load: 1,234 BTU/h Cooling Load: 678 BTU/h garbage",
      "Heating Load: 1,234 BTU Cooling Load: 678 BTU/h",
    ] {
      #expect(throws: (any Error).self) { try RoomLoads().parse(line) }
    }
  }

  @Test
  func fieldsPreserveUnicodeNamesAndStopAtWhitespace() throws {
    var name = "Other fields\nRoom name:\tChambre d’été – 北\r\nNext field: 1"[...].utf8
    let parsedName = try ReportField(label: "Room name:", wholeLine: true).parse(&name)
    #expect(parsedName == "Chambre d’été – 北")
    #expect(String(decoding: name, as: UTF8.self) == "\r\nNext field: 1")
    var number = "Total Cooling BTUH: 1,234\u{00A0}Other field: 5"[...].utf8
    #expect(try ReportField(label: "Total Cooling BTUH:").parse(&number) == "1,234")
  }

  @Test(arguments: [" ", "\t"])
  func emptyNameFieldsAreNotSkipped(whitespace: String) throws {
    var input = "Room name:\(whitespace)\nRoom name: Bedroom"[...].utf8
    let parser = ReportField(label: "Room name:", wholeLine: true)
    #expect(try parser.parse(&input) == "")
    #expect(try parser.parse(&input) == "Bedroom")
  }

  @Test
  func duplicateFieldAfterEmptyOccurrenceStillRejectsReport() throws {
    let text = """
      Project Name: Sample
      OUTDOOR DESIGN CONDITIONS
      LOAD CALCULATION TOTALS
      HVAC System: Main
      SHR: 0.833
      Heated square footage: 100
      Cooled square footage: 100
      ROOM DETAIL
      Room name: Test Room
      Total Heating BTUH: 1,000
      Total Cooling BTUH: 500
      Total Cooling BTUH:
      Total Cooling BTUH: 600
      Heated square footage: 100
      Cooled square footage: 100
      """
    #expect(throws: (any Error).self) { try RoomDetailParser.parse(text) }
  }
}
