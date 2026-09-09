import Foundation

public enum GuidedPath {
  public enum InitialValuesError: Error { case invalid }

  public struct InitialValues: Codable, Equatable, Sendable {
    public let name: String
    public let type: EquivalentLength.EffectiveLengthType?
    public let straightLengths: [Int]

    public init(draft: String) throws {
      guard draft.utf8.count <= 4096 else {
        throw InitialValuesError.invalid
      }
      self = try JSONDecoder().decode(Self.self, from: Data(draft.utf8))
      guard name.count <= 200, straightLengths.count <= 100,
        straightLengths.allSatisfy({ $0 > 0 })
      else { throw InitialValuesError.invalid }
    }
  }

  public struct SaveRequest: Codable, Equatable, Sendable {
    public let id: EquivalentLength.ID?
    public let revision: UUID?
    public let name: String
    public let straightLengths: [Int]
    public let snapshot: PathTemplate.Snapshot
    public let rows: [Row]

    public init(
      id: EquivalentLength.ID? = nil, name: String, straightLengths: [Int],
      snapshot: PathTemplate.Snapshot, rows: [Row], revision: UUID? = nil
    ) {
      self.id = id
      self.revision = revision
      self.name = name
      self.straightLengths = straightLengths
      self.snapshot = snapshot
      self.rows = rows
    }
  }

  public struct Row: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let stepID: UUID?
    public let fittingID: TemplateFitting.ID
    public let inputs: TemplateFitting.Inputs
    public let quantity: Int

    public init(
      id: UUID, stepID: UUID?, fittingID: TemplateFitting.ID, inputs: TemplateFitting.Inputs,
      quantity: Int
    ) {
      self.id = id
      self.stepID = stepID
      self.fittingID = fittingID
      self.inputs = inputs
      self.quantity = quantity
    }
  }
}
