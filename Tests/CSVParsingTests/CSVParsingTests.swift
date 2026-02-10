import CSVParser
import Foundation
import Testing

@Suite
struct CSVParsingTests {

  @Test
  func roomParsing() async throws {

    let parser = CSVParser.liveValue

    let input = """
      Name,Level,Heating Load,Cooling Total,Cooling Sensible,Register Count,Delegated To
      Bed-1,2,12345,2345,2345,2,
      Entry,1,3456,1234,990,1,
      Kitchen,1,6789,3456,,2,
      Bath-1,1,890,,345,0,Kitchen
      """
    let rooms = try await parser.parseRooms(.init(file: Data(input.utf8)))

    #expect(rooms.count == 4)
    #expect(rooms.first!.level == 2)
  }
}
