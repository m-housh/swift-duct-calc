import Elementary
import Foundation
import ManualDCore
import Styleguide

enum PickerFields {
  static func fields(_ requirement: Fitting.InputRequirement, base: Bool = false) -> [PickerField] {
    func pick(_ name: String, _ label: String, _ choices: [(String, String)]) -> PickerField {
      .init(name: name, label: label, choices: choices, kind: "select")
    }
    switch requirement {
    case .fixed: return []
    case .heightWidth(let ratios):
      return [
        .init(
          name: "height", label: "Height (inches)",
          help:
            "Published H/W ratios: \(ratios.map(String.init(describing:)).joined(separator: ", "))"),
        .init(name: "width", label: "Width (inches)"),
      ]
    case .radiusWidth(let ratios):
      return [
        .init(
          name: "radius", label: "Inside radius (inches)",
          help:
            "Published R/W ratios: \(ratios.map(String.init(describing:)).joined(separator: ", "))"),
        .init(name: "width", label: "Width (inches)"),
      ]
    case .downstreamBranches:
      return [
        .init(
          name: "count", label: "Downstream branches", kind: "integer",
          help: "Count to the next reducer or trunk end.")
      ]
    case .plenumReturns:
      return [.init(name: "count", label: "Returns entering the plenum", kind: "integer")]
    case .junction:
      return [
        pick(
          "junctionPath", "Route through junction", [("branch", "Branch"), ("main", "Main trunk")])
      ]
    case .returnJunction:
      return [
        .init(name: "branchCFM", label: "Branch airflow (CFM1)"),
        .init(name: "totalCFM", label: "Combined downstream airflow (CFM2)"),
      ]
    case .pannedReturn(let rows, let merging):
      return [
        .init(
          name: "airflowCFM", label: "Airflow (CFM)",
          help:
            "Supported range: \(rows.first ?? 0)–\(rows.last ?? 0) CFM. Nearest published row; midpoint ties upward."
        )
      ]
        + (merging
          ? [.init(name: "mergingFlow", label: "Merging flow (+40 ft)", kind: "checkbox")] : [])
    case .roundElbow(let ratios, let angles):
      return [
        pick("radiusRatio", "R/D", ratios.map { (String($0.rawValue), $0.label) }),
        base
          ? .init(name: "angle", label: "90°", kind: "hidden")
          : pick("angle", "Angle", angles.map { (String($0.rawValue), $0.label) }),
      ]
    case .rectangularElbow(let ratios, let categories, let angles):
      return [
        pick("radiusRatio", "R/W", ratios.map { (String($0.rawValue), $0.label) }),
        pick("bendCategory", "Bend category", categories.map { ($0.rawValue, $0.label) }),
        base
          ? .init(name: "angle", label: "90°", kind: "hidden")
          : pick("angle", "Angle", angles.map { (String($0.rawValue), $0.label) }),
      ]
    case .ovalElbow(let counts):
      return [pick("pieceCount", "Construction", counts.map { (String($0.rawValue), $0.label) })]
    case .squareElbow(let categories):
      return [pick("bendCategory", "Bend category", categories.map { ($0.rawValue, $0.label) })]
    case .steppedOffset(let ratios):
      return [pick("offsetRatio", "L/H", ratios.map { (String($0.rawValue), $0.label) })]
    case .fourTurnOffset(let ratios, _):
      return [
        pick("offsetRatio", "H/L", ratios.map { (String($0.rawValue), $0.label) }),
        .init(name: "turningVanes", label: "With turning vanes", kind: "checkbox"),
      ]
    case .radiusOffset(let ratios):
      return [pick("offsetRatio", "R/H", ratios.map { (String($0.rawValue), $0.label) })]
    case .riserElbow(let sizes, let corners):
      return [
        pick("riserSize", "Riser size", sizes.map { ($0.rawValue, $0.label) }),
        pick("riserCorner", "Inside corners", corners.map { ($0.rawValue, $0.label) }),
      ]
    case .insideCornerOffset(let radii):
      return [
        pick("insideCornerRadius", "Inside corner radius", radii.map { ($0.rawValue, $0.label) })
      ]
    case .doubleElbow: return []  // Base options are resolved from catalog IDs by the controller.
    case .easedTakeoff:
      return [
        .init(
          name: "buttedSleeve", label: "Round sleeve simply butted to transition wall (+15 ft)",
          kind: "checkbox")
      ]
    case .transition(let slopes, let ratios):
      return [
        pick("slope", "Slope (X/Y)", slopes.map { ($0.rawValue, $0.label) }),
        pick(
          "areaRatio", "Larger area / smaller area", ratios.map { (String($0.rawValue), $0.label) }),
      ]
    case .plenumPassage(let inlet, let outlet):
      return [
        pick("inletVelocity", "Inlet velocity", inlet.map { (String($0.rawValue), $0.label) }),
        pick("outletVelocity", "Outlet velocity", outlet.map { (String($0.rawValue), $0.label) }),
      ]
    case .abruptSqueeze(let velocities, let ratios):
      return [
        pick(
          "upstreamVelocity", "Upstream velocity at A1",
          velocities.map { (String($0.rawValue), $0.label) }),
        pick(
          "areaRatio", "Larger area / smaller area", ratios.map { (String($0.rawValue), $0.label) }),
      ]
    case .flexJunctionBox(let velocities, let ratios):
      return [
        pick(
          "flexVelocity", "Velocity in flex duct",
          velocities.map { (String($0.rawValue), $0.label) }),
        pick(
          "flexOpenings", "Entrance or exits",
          Fitting.FlexOpenings.allCases.map { ($0.rawValue, $0.label) }),
        .init(name: "suppliedBend", label: "Supplied with a 90° radius bend", kind: "checkbox"),
        pick("bendVelocity", "Bend velocity", velocities.map { (String($0.rawValue), $0.label) }),
        pick("bendRadiusRatio", "Bend R/D", ratios.map { ($0.rawValue, $0.label) }),
      ]
    }
  }

  static func defaults(_ inputs: Fitting.Inputs) -> [String: String] {
    func raw<T: RawRepresentable>(_ value: T?) -> String {
      value.map { String(describing: $0.rawValue) } ?? ""
    }
    func n<T>(_ value: T?) -> String { value.map { String(describing: $0) } ?? "" }
    switch inputs {
    case .fixed: return [:]
    case .heightWidth(let h, let w): return ["height": n(h), "width": n(w)]
    case .radiusWidth(let r, let w): return ["radius": n(r), "width": n(w)]
    case .downstreamBranches(let count), .plenumReturns(let count): return ["count": n(count)]
    case .junction(let path): return ["junctionPath": raw(path)]
    case .returnJunction(let b, let t): return ["branchCFM": n(b), "totalCFM": n(t)]
    case .pannedReturn(let cfm, let merging):
      return ["airflowCFM": n(cfm), "mergingFlow": String(merging)]
    case .roundElbow(let ratio, let angle): return ["radiusRatio": raw(ratio), "angle": raw(angle)]
    case .rectangularElbow(let ratio, let category, let angle):
      return ["radiusRatio": raw(ratio), "bendCategory": raw(category), "angle": raw(angle)]
    case .ovalElbow(let count): return ["pieceCount": raw(count)]
    case .squareElbow(let category): return ["bendCategory": raw(category)]
    case .steppedOffset(let ratio): return ["offsetRatio": raw(ratio)]
    case .fourTurnOffset(let ratio, let vanes):
      return ["offsetRatio": raw(ratio), "turningVanes": String(vanes)]
    case .radiusOffset(let ratio): return ["offsetRatio": raw(ratio)]
    case .riserElbow(let size, let corner):
      return ["riserSize": raw(size), "riserCorner": raw(corner)]
    case .insideCornerOffset(let radius): return ["insideCornerRadius": raw(radius)]
    case .easedTakeoff(let butted): return ["buttedSleeve": String(butted)]
    case .transition(let slope, let ratio): return ["slope": raw(slope), "areaRatio": raw(ratio)]
    case .plenumPassage(let inlet, let outlet):
      return ["inletVelocity": raw(inlet), "outletVelocity": raw(outlet)]
    case .abruptSqueeze(let upstream, let ratio):
      return ["upstreamVelocity": raw(upstream), "areaRatio": raw(ratio)]
    case .flexJunctionBox(let velocity, let openings, let supplied, let bendVelocity, let ratio):
      return [
        "flexVelocity": raw(velocity), "flexOpenings": raw(openings),
        "suppliedBend": String(supplied), "bendVelocity": raw(bendVelocity),
        "bendRadiusRatio": raw(ratio),
      ]
    case .doubleElbow(let id, let inputs):
      guard let id, let inputs else { return [:] }
      return ["baseFitting": id.rawValue].merging(
        Dictionary(uniqueKeysWithValues: defaults(inputs).map { ("base." + $0.key, $0.value) })
      ) { _, new in new }
    }
  }

  static func parse(
    _ definition: Fitting.Definition, fields: [String: String], definitions: [Fitting.Definition],
    prefix: String = ""
  ) throws -> Fitting.Inputs {
    func text(_ key: String) -> String? {
      guard let value = fields[prefix + key]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty
      else { return nil }
      return value
    }
    func number<T: LosslessStringConvertible>(_ key: String, _: T.Type) throws -> T? {
      guard let value = text(key) else { return nil }
      guard let parsed = T(value) else { throw PickerError("Enter a valid number for \(key).") }
      return parsed
    }
    func choice<T: RawRepresentable>(_ key: String, _: T.Type) throws -> T?
    where T.RawValue: LosslessStringConvertible {
      guard let value = text(key) else { return nil }
      guard let raw = T.RawValue(value), let parsed = T(rawValue: raw) else {
        throw PickerError("Choose a listed option for \(key).")
      }
      return parsed
    }
    func flag(_ key: String) throws -> Bool {
      guard let value = text(key) else { return false }
      guard value == "true" || value == "false" else {
        throw PickerError("Invalid checkbox value.")
      }
      return value == "true"
    }
    switch definition.inputRequirement {
    case .fixed: return .fixed
    case .heightWidth:
      return try .heightWidth(
        heightInches: number("height", Double.self), widthInches: number("width", Double.self))
    case .radiusWidth:
      return try .radiusWidth(
        radiusInches: number("radius", Double.self), widthInches: number("width", Double.self))
    case .downstreamBranches: return try .downstreamBranches(count: number("count", Int.self))
    case .plenumReturns: return try .plenumReturns(count: number("count", Int.self))
    case .junction: return try .junction(path: choice("junctionPath", Fitting.JunctionPath.self))
    case .returnJunction:
      return try .returnJunction(
        branchCFM: number("branchCFM", Double.self), totalCFM: number("totalCFM", Double.self))
    case .pannedReturn:
      return try .pannedReturn(
        airflowCFM: number("airflowCFM", Double.self), mergingFlow: flag("mergingFlow"))
    case .roundElbow:
      return try .roundElbow(
        radiusRatio: choice("radiusRatio", Fitting.RoundElbowRadiusRatio.self),
        angle: choice("angle", Fitting.ElbowAngle.self))
    case .rectangularElbow:
      return try .rectangularElbow(
        radiusRatio: choice("radiusRatio", Fitting.RectangularElbowRadiusRatio.self),
        bendCategory: choice("bendCategory", Fitting.ElbowBendCategory.self),
        angle: choice("angle", Fitting.ElbowAngle.self))
    case .ovalElbow:
      return try .ovalElbow(pieceCount: choice("pieceCount", Fitting.OvalElbowPieceCount.self))
    case .squareElbow:
      return try .squareElbow(bendCategory: choice("bendCategory", Fitting.ElbowBendCategory.self))
    case .steppedOffset:
      return try .steppedOffset(
        lengthHeightRatio: choice("offsetRatio", Fitting.OffsetLengthHeightRatio.self))
    case .fourTurnOffset:
      return try .fourTurnOffset(
        heightLengthRatio: choice("offsetRatio", Fitting.OffsetHeightLengthRatio.self),
        turningVanes: flag("turningVanes"))
    case .radiusOffset:
      return try .radiusOffset(
        radiusHeightRatio: choice("offsetRatio", Fitting.OffsetRadiusHeightRatio.self))
    case .riserElbow:
      return try .riserElbow(
        size: choice("riserSize", Fitting.RiserSize.self),
        corner: choice("riserCorner", Fitting.RiserCorner.self))
    case .insideCornerOffset:
      return try .insideCornerOffset(
        radius: choice("insideCornerRadius", Fitting.InsideCornerRadius.self))
    case .easedTakeoff: return try .easedTakeoff(buttedSleeve: flag("buttedSleeve"))
    case .transition:
      return try .transition(
        slope: choice("slope", Fitting.TransitionSlope.self),
        areaRatio: choice("areaRatio", Fitting.TransitionAreaRatio.self))
    case .plenumPassage:
      return try .plenumPassage(
        inletVelocity: choice("inletVelocity", Fitting.TransitionVelocity.self),
        outletVelocity: choice("outletVelocity", Fitting.TransitionVelocity.self))
    case .abruptSqueeze:
      return try .abruptSqueeze(
        upstreamVelocity: choice("upstreamVelocity", Fitting.TransitionVelocity.self),
        areaRatio: choice("areaRatio", Fitting.TransitionAreaRatio.self))
    case .flexJunctionBox:
      return try .flexJunctionBox(
        boxVelocity: choice("flexVelocity", Fitting.FlexVelocity.self),
        openings: choice("flexOpenings", Fitting.FlexOpenings.self),
        suppliedBend: flag("suppliedBend"),
        bendVelocity: choice("bendVelocity", Fitting.FlexVelocity.self),
        bendRadiusRatio: choice("bendRadiusRatio", Fitting.FlexBendRadiusRatio.self))
    case .doubleElbow(let ids):
      guard prefix.isEmpty else { throw PickerError("An elbow pair cannot contain another pair.") }
      guard let id = text("baseFitting") else {
        return .doubleElbow(baseFittingID: nil, baseInputs: nil)
      }
      guard ids.contains(where: { $0.rawValue == id }),
        let base = definitions.first(where: { $0.id.rawValue == id })
      else { throw PickerError("Choose a compatible base elbow.") }
      return try .doubleElbow(
        baseFittingID: base.id,
        baseInputs: parse(base, fields: fields, definitions: definitions, prefix: "base."))
    }
  }
}

struct PickerError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}
