import Foundation

public enum GuidedPath {
  public struct SaveRequest: Codable, Equatable, Sendable {
    public let id: EquivalentLength.ID?
    public let name: String
    public let straightLengths: [Int]
    public let snapshot: PathTemplate.Snapshot
    public let rows: [Row]

    public init(
      id: EquivalentLength.ID? = nil, name: String, straightLengths: [Int],
      snapshot: PathTemplate.Snapshot, rows: [Row]
    ) {
      self.id = id
      self.name = name
      self.straightLengths = straightLengths
      self.snapshot = snapshot
      self.rows = rows
    }
  }

  public struct Row: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let stepID: UUID?
    public let fittingID: Fitting.ID
    public let inputs: Fitting.Inputs
    public let quantity: Int

    public init(
      id: UUID, stepID: UUID?, fittingID: Fitting.ID, inputs: Fitting.Inputs, quantity: Int
    ) {
      self.id = id
      self.stepID = stepID
      self.fittingID = fittingID
      self.inputs = inputs
      self.quantity = quantity
    }
  }
}
