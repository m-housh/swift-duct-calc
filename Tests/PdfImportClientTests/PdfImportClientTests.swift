import Dependencies
import Foundation
import ManualDCore
import Testing

@testable import PdfImportClient

@Suite(.serialized)
struct PdfImportClientTests {
  private func fixture() throws -> String {
    try String(
      contentsOf: #require(
        Bundle.module.url(forResource: "cool-calc", withExtension: "txt", subdirectory: "Resources")
      ), encoding: .utf8)
  }

  @Test(arguments: ["Ohio 45223", "OH 45223-1234", "New York 10001"])
  func projectMetadata(region: String) throws {
    let text =
      "Project Name: Example House\nAddress: 123 Example Street, Unit 2, Example City, \(region), United States\n"
      + (try fixture())
    let result = try CoolCalcParser.parseProject(text)
    #expect(result.project.name == "Example House")
    #expect(result.project.streetAddress == "123 Example Street, Unit 2")
    #expect(result.project.city == "Example City")
    #expect(result.project.state == region.split(separator: " ").dropLast().joined(separator: " "))
    #expect(result.project.zipCode == String(region.split(separator: " ").last!))
    #expect(result.project.sensibleHeatRatio == 0.88)
    #expect(result.rooms.count == 17)
  }

  @Test
  func rejectsIncompleteProjectMetadata() throws {
    let rooms = try fixture()
    for header in [
      "", "Project Name: House\nAddress: unknown\n",
      "Project Name: \nAddress: 123 Main St, City, OH 12345\n",
    ] {
      #expect(throws: RoomImportError.self) { try CoolCalcParser.parseProject(header + rooms) }
    }
    #expect(throws: RoomImportError.self) {
      try CoolCalcParser.parseProject(
        ("Project Name: House\nAddress: 123 Main St, City, OH 12345\n" + rooms)
          .replacingOccurrences(of: "SHR: 0.880", with: ""))
    }
  }

  @Test
  func sampleRoomAnalysis() throws {
    let result = try CoolCalcParser.parse(fixture())
    let expected: [(String, Int, Double, Double)] = [
      ("Room 1 (Basement)", -1, 4480, 814),
      ("Room 2", -1, 5013, 985),
      ("Dining", 1, 3846, 1668),
      ("Foyer", 1, 3320, 892),
      ("Kitchen", 1, 3821, 4085),
      ("Living", 1, 3628, 5113),
      ("Room 1 (Level-1)", 1, 322, 66),
      ("Stairway (Basement)", 1, 308, 63),
      ("Bath (1)", 2, 1854, 548),
      ("Bath (2)", 2, 1888, 522),
      ("Bed (1)", 2, 2983, 2365),
      ("Bed (2)", 2, 3289, 2632),
      ("Bed (3)", 2, 1186, 1497),
      ("Hall / Stairwell (up/down)", 2, 1332, 314),
      ("Laundry", 2, 1466, 1175),
      ("Level 3", 3, 10010, 2995),
      ("Room 1 (Level-3)", 3, 4152, 2630),
    ]
    #expect(result.sensibleHeatRatio == 0.880)
    #expect(result.rooms.count == expected.count)
    for (room, values) in zip(result.rooms, expected) {
      #expect(room.name == values.0)
      #expect(room.level?.rawValue == values.1)
      #expect(room.heatingLoad == values.2)
      #expect(room.coolingTotal == values.3)
      #expect(room.coolingSensible == nil)
      #expect(room.registerCount == 1)
      #expect(room.delegatedTo == nil)
    }
    #expect(result.rooms.reduce(0) { $0 + $1.heatingLoad } == 52898)
    #expect(result.rooms.reduce(0) { $0 + ($1.coolingTotal ?? 0) } == 28364)
    let kitchen = try #require(result.rooms.first { $0.name == "Kitchen" })
    #expect(try kitchen.coolingLoad.ensured(shr: 0.88).sensible == 4085 * 0.88)
    #expect(try kitchen.coolingLoad.ensured(shr: 0.8).sensible == 4085 * 0.8)
  }

  @Test
  func ignoresSummaryLoadsAndSupportsPageBreakInsideRoom() throws {
    let text = """
      MJ8 Report
      LOADS BREAKDOWN SUMMARY
      Level 1 - Dining  2,905 1,456 1,456 0
      SHR: 0.880
      INDIVIDUAL ROOM ANALYSIS
      Dining - Level: Level 1
      Page 9 of 12
      \u{000C}
      Heating Load: 3,846 BTU/h   Cooling Load: 1,668 BTU/h
      """
    let result = try CoolCalcParser.parse(text)
    #expect(result.rooms.count == 1)
    #expect(result.rooms[0].heatingLoad == 3846)
    #expect(throws: RoomImportError.self) {
      try CoolCalcParser.parse(
        text.replacingOccurrences(
          of: "SHR: 0.880", with: "Level 1 - Missing Bedroom  1,000 400 400 0\nSHR: 0.880"))
    }
  }

  @Test(arguments: [
    "",
    "MJ8 Report\nLOADS BREAKDOWN SUMMARY",
    "MJ8 Report\nINDIVIDUAL ROOM ANALYSIS",
    "MJ8 Report\nINDIVIDUAL ROOM ANALYSIS\nBedroom - Level: Level 1",
    "MJ8 Report\nINDIVIDUAL ROOM ANALYSIS\nBedroom - Level: Level 1\nHeating Load: 1,200 BTU/h Cooling Load: -4 BTU/h",
    "MJ8 Report\nINDIVIDUAL ROOM ANALYSIS\nBedroom - Level: Attic\nHeating Load: 1,200 BTU/h Cooling Load: 400 BTU/h",
    "MJ8 Report\nINDIVIDUAL ROOM ANALYSIS\nINDIVIDUAL ROOM ANALYSIS",
  ])
  func rejectsUnsupportedOrIncompleteText(text: String) {
    #expect(throws: RoomImportError.self) { try CoolCalcParser.parse(text) }
  }

  @Test
  func rejectsPartialAndDuplicateRooms() throws {
    let text = try fixture()
    for changed in [
      text.replacingOccurrences(of: "4,480", with: "unreadable"),
      text.replacingOccurrences(of: "3,821", with: "3,82"),
      text.replacingOccurrences(of: "Room 2 - Level: Basement", with: "Room 1 - Level: Basement"),
      text.replacingOccurrences(of: "SHR: 0.880", with: "SHR: 0.880\nSHR: 0.750"),
      text.replacingOccurrences(of: "SHR: 0.880", with: "SHR: 1.2"),
      text.replacingOccurrences(of: "SHR: 0.880", with: "SHR: unknown"),
    ] {
      #expect(throws: RoomImportError.self) { try CoolCalcParser.parse(changed) }
    }
  }

  @Test
  func pdfExtraction() async throws {
    let url = try #require(
      Bundle.module.url(forResource: "cool-calc", withExtension: "pdf", subdirectory: "Resources"))
    let parsed = try await PdfImportClient.liveValue.parseRooms(.init(file: Data(contentsOf: url)))
    #expect(parsed == (try CoolCalcParser.parse(fixture())))
  }

  @Test
  func exampleHouseReferenceUsesRoomDetailLayout() async throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "ExampleHouse_ManJ", withExtension: "pdf", subdirectory: "Resources"))
    let pdf = Room.PDF(file: try Data(contentsOf: url))
    let result = try await PdfImportClient.liveValue.parseProject(pdf)
    #expect(result.project.name == "Example House")
    #expect(result.project.streetAddress == "16 South Main Street")
    #expect(result.project.city == "Monroe")
    #expect(result.project.state == "OH")
    #expect(result.project.zipCode.isEmpty)
    #expect(result.project.sensibleHeatRatio == 0.833)
    let expected: [(String, Double, Double)] = [
      ("Entry", 7659, 2916), ("Master", 7577, 2076), ("Bedroom-1", 3288, 2472),
      ("Living Room", 6945, 6829), ("Kitchen", 3893, 5069), ("Family Room", 9160, 7446),
    ]
    #expect(result.rooms.count == expected.count)
    for (room, values) in zip(result.rooms, expected) {
      #expect(room.name == values.0)
      #expect(room.heatingLoad == values.1)
      #expect(room.coolingTotal == values.2)
      #expect(room.coolingSensible == nil && room.level == nil)
    }
    #expect(result.rooms.reduce(0) { $0 + $1.heatingLoad } == 38522)
    #expect(result.rooms.reduce(0) { $0 + ($1.coolingTotal ?? 0) } == 26808)
  }

  @Test
  func rejectsIncompleteRoomDetail() throws {
    let header = """
      Project Name: Sample
      OUTDOOR DESIGN CONDITIONS
      LOAD CALCULATION TOTALS
      HVAC System: Main
      SHR: 0.833
      Heated square footage: 100
      Cooled square footage: 100
      """
    let room = """
      ROOM DETAIL
      Room name: Test Room
      Total Heating BTUH: 1,000
      Total Cooling BTUH: 500
      Heated square footage: 100
      Cooled square footage: 100
      """
    let text = header + "\n" + room
    #expect(try CoolCalcParser.parse(text).rooms.count == 1)
    for invalid in [
      text + "\n" + room,
      text.replacingOccurrences(of: "Total Cooling BTUH: 500", with: ""),
      text.replacingOccurrences(of: "1,000", with: "1,00"),
      text.replacingOccurrences(of: "SHR: 0.833", with: "SHR: 0.833\nSHR: 0.8"),
      header.replacingOccurrences(of: "footage: 100", with: "footage: 200") + "\n" + room,
      text + "\nINDIVIDUAL ROOM ANALYSIS",
      text.replacingOccurrences(
        of: "HVAC System: Main", with: "HVAC System: Main\nHVAC System: Upstairs"),
    ] {
      #expect(throws: RoomImportError.self) { try CoolCalcParser.parse(invalid) }
    }
  }

  @Test
  func invalidPDF() async throws {
    await #expect(throws: RoomImportError.self) {
      try await PdfImportClient.liveValue.parseRooms(.init(file: Data("not a PDF".utf8)))
    }
    await #expect(throws: RoomImportError.self) {
      try await PdfImportClient.liveValue.parseRooms(.init(file: Data("%PDF-broken".utf8)))
    }
    await #expect(throws: RoomImportError.self) {
      try await PdfImportClient.liveValue.parseRooms(
        .init(file: Data(repeating: 0, count: 10 * 1024 * 1024 + 1)))
    }
  }

  @Test
  func missingExecutable() async throws {
    try await withDependencies {
      $0.environment = .init(pdfToTextPath: "/missing/pdftotext")
    } operation: {
      await #expect(
        throws: RoomImportError(
          "PDF import is unavailable. The server needs Poppler's pdftotext installed.")
      ) {
        try await PdfImportClient.liveValue.parseRooms(.init(file: Data("%PDF-1.3".utf8)))
      }
    }
  }
}
