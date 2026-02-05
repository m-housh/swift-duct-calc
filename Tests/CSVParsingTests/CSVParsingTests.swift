import CSVParser
import Foundation
import Testing

@Suite
struct CSVParsingTests {

  @Test
  func roomParsing() async throws {

    let parser = CSVParser.liveValue

    let input = """
      Name,Heating Load,Cooling Total,Cooling Sensible,Register Count
      Bed-1,12345,12345,,2
      Bed-2,1223,,1123,1
      """
    let rooms = try await parser.parseRooms(.init(file: Data(input.utf8)))

    #expect(rooms.count == 2)
  }
}
