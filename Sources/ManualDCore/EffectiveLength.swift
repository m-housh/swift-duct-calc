import Foundation

// TODO: Not sure how to model effective length groups in the database.
//       thinking perhaps just have a 'data' field that encoded / decodes
//       to swift types??
public struct EffectiveLength: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let projectID: Project.ID
  public let name: String
  public let type: EffectiveLengthType
  public let straightLengths: [Int]
  public let groups: [Group]
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    projectID: Project.ID,
    name: String,
    type: EffectiveLength.EffectiveLengthType,
    straightLengths: [Int],
    groups: [EffectiveLength.Group],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.projectID = projectID
    self.name = name
    self.type = type
    self.straightLengths = straightLengths
    self.groups = groups
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension EffectiveLength {

  public struct Create: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let name: String
    public let type: EffectiveLengthType
    public let straightLengths: [Int]
    public let groups: [Group]

    public init(
      projectID: Project.ID,
      name: String,
      type: EffectiveLength.EffectiveLengthType,
      straightLengths: [Int],
      groups: [EffectiveLength.Group]
    ) {
      self.projectID = projectID
      self.name = name
      self.type = type
      self.straightLengths = straightLengths
      self.groups = groups
    }
  }

  public enum EffectiveLengthType: String, CaseIterable, Codable, Sendable {
    case `return`
    case supply
  }

  public struct Group: Codable, Equatable, Sendable {

    public let group: Int
    public let letter: String
    public let value: Double
    public let quantity: Int

    public init(
      group: Int,
      letter: String,
      value: Double,
      quantity: Int = 1
    ) {
      self.group = group
      self.letter = letter
      self.value = value
      self.quantity = quantity
    }
  }
}
