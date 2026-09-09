import Foundation
import ManualDCore

/// Parser for Cool Calc MJ8 Individual Room Analysis and Room Detail exports.
/// Both layouts report total cooling in their per-room load fields.
enum CoolCalcParser {
  static func parseProject(_ text: String) throws -> Project.PDFImport {
    let loads = try parse(text)
    guard let shr = loads.sensibleHeatRatio else {
      throw RoomImportError(
        "The report has no SHR. Create a project manually, set its sensible heat ratio, then import the rooms."
      )
    }
    // Only use the cover page, avoiding repeated headers or contractor addresses later on.
    let cover = text.components(separatedBy: "\u{000C}")[0]
    let namePattern = try NSRegularExpression(pattern: #"(?m)^[ \t]*Project Name:[ \t]*(.+)$"#)
    let addressPattern = try NSRegularExpression(pattern: #"(?m)^[ \t]*Address:[ \t]*(.+)$"#)
    guard
      let name = captures(namePattern, in: cover)?.first?.trimmingCharacters(
        in: .whitespacesAndNewlines),
      !name.isEmpty,
      let address = captures(addressPattern, in: cover)?.first
    else {
      throw RoomImportError(
        "Could not read the project name and address. Create a project manually, then import the rooms."
      )
    }
    var parts = address.components(separatedBy: ",").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let country = parts.last?.lowercased(),
      ["united states", "united states of america", "usa", "us"].contains(country)
    {
      parts.removeLast()
    }
    let stateZip = try NSRegularExpression(
      pattern: #"^([A-Za-z][A-Za-z .]*?)(?:[ \t]+(\d{5}(?:-\d{4})?))?$"#)
    guard parts.count >= 3, let region = parts.last,
      let fields = captures(stateZip, in: region),
      parts.allSatisfy({ !$0.isEmpty })
    else {
      throw RoomImportError(
        "Could not separate the report's street address, city, state, and ZIP code. Create a project manually, then import the rooms."
      )
    }
    return .init(
      project: .init(
        name: name, streetAddress: parts.dropLast(2).joined(separator: ", "),
        city: parts[parts.count - 2], state: fields[0], zipCode: fields.count > 1 ? fields[1] : "",
        sensibleHeatRatio: shr),
      rooms: loads.rooms)
  }

  static func parse(_ text: String) throws -> Room.LoadImport {
    if text.contains("ROOM DETAIL") { return try RoomDetailParser.parse(text) }
    let heading = "INDIVIDUAL ROOM ANALYSIS"
    let sections = text.components(separatedBy: heading)
    guard text.contains("MJ8 Report"), sections.count == 2 else {
      throw RoomImportError(
        "Expected one Cool Calc MJ8 Individual Room Analysis section. Scanned PDFs and reports with multiple systems are not supported yet."
      )
    }

    let number = #"(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?"#
    let header = try NSRegularExpression(
      pattern: #"^(.+?)\s+-\s+Level:\s*(Basement|Level\s+\d+)\s*$"#)
    let loads = try NSRegularExpression(
      pattern: "^Heating Load:\\s*(\(number))\\s*BTU/h\\s+Cooling Load:\\s*(\(number))\\s*BTU/h$")

    struct Draft {
      let name: String
      let level: Room.Level
      var heating: Double?
      var cooling: Double?
    }
    var drafts: [Draft] = []
    // Page breaks and page-number footers can occur between a room heading and its loads.
    let lines = sections[1].replacingOccurrences(of: "\u{000C}", with: "\n")
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    for line in lines {
      if line.isEmpty || line.range(of: #"^Page \d+ of \d+$"#, options: .regularExpression) != nil {
        continue
      }
      if let fields = captures(header, in: line) {
        guard drafts.last == nil || drafts.last?.heating != nil else {
          throw RoomImportError(
            "A room is missing its heating or cooling load. No rooms were imported.")
        }
        guard
          let level = fields[1] == "Basement" ? -1 : Int(fields[1].split(separator: " ").last ?? "")
        else {
          throw RoomImportError("A room has an unreadable level. No rooms were imported.")
        }
        drafts.append(.init(name: fields[0], level: .init(rawValue: level)))
      } else if line.hasPrefix("Heating Load:") || line.hasPrefix("Cooling Load:") {
        guard !drafts.isEmpty, drafts[drafts.count - 1].heating == nil,
          let fields = captures(loads, in: line),
          let heating = value(fields[0]), let cooling = value(fields[1]),
          heating >= 0, cooling > 0
        else {
          throw RoomImportError("A room has an unreadable or invalid load. No rooms were imported.")
        }
        drafts[drafts.count - 1].heating = heating
        drafts[drafts.count - 1].cooling = cooling
      } else if line.hasPrefix("Airflow:") || line.hasPrefix("Area:")
        || line.hasPrefix("Exposed Wall Area:")
      {
        continue
      } else if !drafts.isEmpty, drafts.last?.heating != nil,
        line.range(of: #"^.+ - (Basement|Level \d+)$"#, options: .regularExpression) != nil
      {
        // The construction detail section begins after the individual room analysis.
        break
      } else {
        throw RoomImportError(
          "The Cool Calc room analysis layout was not recognized. No rooms were imported.")
      }
    }
    guard !drafts.isEmpty, drafts.allSatisfy({ $0.heating != nil && $0.cooling != nil }) else {
      throw RoomImportError(
        "No complete room loads were found. Use a text-based Cool Calc MJ8 report.")
    }

    var usedKeys = Set<String>()
    let nameCounts = Dictionary(grouping: drafts, by: { $0.name.lowercased() }).mapValues(\.count)
    var usedNames = Set<String>()
    let rooms = try drafts.map { draft -> Room.Create in
      let key = "\(draft.level.rawValue):\(draft.name.lowercased())"
      guard usedKeys.insert(key).inserted else {
        throw RoomImportError(
          "The report repeats a room on the same level. Import one HVAC system at a time.")
      }
      let name =
        nameCounts[draft.name.lowercased(), default: 0] > 1
        ? "\(draft.name) (\(draft.level.label))" : draft.name
      guard usedNames.insert(name.lowercased()).inserted else {
        throw RoomImportError("The report contains conflicting room names. No rooms were imported.")
      }
      return .init(
        name: name, level: draft.level, heatingLoad: draft.heating!,
        coolingTotal: draft.cooling!, registerCount: 1)
    }

    // When a summary is present, use its room identities to detect missing analysis pages.
    // Its load values exclude infiltration and must not be substituted for analysis loads.
    if let summaryStart = sections[0].range(of: "LOADS BREAKDOWN SUMMARY") {
      let summary = String(sections[0][summaryStart.upperBound...])
      let summaryRow = try NSRegularExpression(
        pattern: #"(?m)^[ \t]*(Basement|Level[ \t]+\d+)[ \t]+-[ \t]+(.+?)[ \t]{2,}\d"#)
      var summaryKeys = Set<String>()
      let matches = summaryRow.matches(
        in: summary, range: NSRange(summary.startIndex..., in: summary))
      for match in matches {
        let levelText = String(summary[Range(match.range(at: 1), in: summary)!])
        let name = String(summary[Range(match.range(at: 2), in: summary)!])
        guard
          let level = levelText == "Basement"
            ? -1 : Int(levelText.split(whereSeparator: \.isWhitespace).last ?? "")
        else {
          throw RoomImportError("A summary room has an unreadable level.")
        }
        summaryKeys.insert("\(level):\(name.lowercased())")
      }
      guard matches.count == drafts.count, summaryKeys == usedKeys else {
        throw RoomImportError(
          "The room analysis does not match the summary's room list. Export the complete report and try again. No rooms were imported."
        )
      }
    }

    let shrPattern = try NSRegularExpression(pattern: #"\bSHR:[ \t]*(\S+)"#)
    let ratios = shrPattern.matches(
      in: sections[0], range: NSRange(sections[0].startIndex..., in: sections[0]))
    guard ratios.count <= 1 else {
      throw RoomImportError(
        "The report contains multiple system SHRs. Import one HVAC system at a time.")
    }
    let shr = captures(shrPattern, in: sections[0]).flatMap { value($0[0]) }
    if !ratios.isEmpty && shr == nil {
      throw RoomImportError("The report's sensible heat ratio could not be read.")
    }
    if let shr, !(shr > 0 && shr <= 1) {
      throw RoomImportError(
        "The report's sensible heat ratio must be greater than zero and at most one.")
    }
    return .init(rooms: rooms, sensibleHeatRatio: shr)
  }

  private static func captures(_ regex: NSRegularExpression, in text: String) -> [String]? {
    guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else {
      return nil
    }
    return (1..<match.numberOfRanges).compactMap {
      Range(match.range(at: $0), in: text).map { String(text[$0]) }
    }
  }

  private static func value(_ text: String) -> Double? {
    guard let number = Double(text.replacingOccurrences(of: ",", with: "")), number.isFinite else {
      return nil
    }
    return number
  }
}
