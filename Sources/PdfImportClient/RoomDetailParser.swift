import Foundation
import ManualDCore
import Parsing

/// Cool Calc's Room Detail export reports total loads without room levels.
enum RoomDetailParser {
  static func parse(_ text: String) throws -> Room.LoadImport {
    let sections = text.components(separatedBy: "ROOM DETAIL")
    let header = sections[0]
    guard sections.count > 1,
      text.components(separatedBy: "LOAD CALCULATION TOTALS").count == 2,
      text.components(separatedBy: "HVAC System:").count == 2,
      header.contains("OUTDOOR DESIGN CONDITIONS"), header.contains("Project Name:"),
      !text.contains("INDIVIDUAL ROOM ANALYSIS")
    else {
      throw RoomImportError("Expected one complete Cool Calc system with Room Detail pages.")
    }
    let shr = try number("SHR:", in: header)
    guard shr > 0, shr <= 1 else {
      throw RoomImportError(
        "The report's sensible heat ratio must be greater than zero and at most one.")
    }
    var names = Set<String>()
    var heatedArea = 0.0
    var cooledArea = 0.0
    let rooms = try sections.dropFirst().map { section -> Room.Create in
      let name = try field("Room name:", in: section, wholeLine: true)
      guard !name.isEmpty, names.insert(name.lowercased()).inserted else {
        throw RoomImportError("Room Detail pages contain an empty or repeated room name.")
      }
      let heating = try number("Total Heating BTUH:", in: section)
      let cooling = try number("Total Cooling BTUH:", in: section)
      guard heating >= 0, cooling > 0 else {
        throw RoomImportError("A room has an invalid heating or cooling load.")
      }
      heatedArea += try number("Heated square footage:", in: section)
      cooledArea += try number("Cooled square footage:", in: section)
      return .init(name: name, heatingLoad: heating, coolingTotal: cooling, registerCount: 1)
    }
    // Component/system loads have a different scope. Compare floor areas to detect
    // omitted Room Detail pages, allowing for each displayed area's rounding.
    let tolerance = Double(rooms.count + 1) * 0.5
    guard abs(heatedArea - (try number("Heated square footage:", in: header))) <= tolerance,
      abs(cooledArea - (try number("Cooled square footage:", in: header))) <= tolerance
    else {
      throw RoomImportError(
        "The Room Detail pages do not account for the system's floor area. Export the complete report and try again."
      )
    }
    return .init(rooms: rooms, sensibleHeatRatio: shr)
  }

  private static func number(_ label: String, in text: String) throws -> Double {
    let raw = try field(label, in: text)
    guard let value = try? ReportNumber().parse(raw)
    else { throw RoomImportError("Could not read \(label) in the Room Detail report.") }
    return value
  }

  private static func field(_ label: String, in text: String, wholeLine: Bool = false) throws
    -> String
  {
    let parser = ReportField(label: label, wholeLine: wholeLine)
    var input = text[...].utf8
    guard let value = try? parser.parse(&input), (try? parser.parse(&input)) == nil else {
      throw RoomImportError("Expected one \(label) field in each Room Detail section.")
    }
    return value
  }
}
