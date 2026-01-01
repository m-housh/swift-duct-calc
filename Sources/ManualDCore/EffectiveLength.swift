import Dependencies
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

#if DEBUG

  extension EffectiveLength {
    public static let mocks: [Self] = [
      .init(
        id: UUID(0),
        projectID: UUID(0),
        name: "Test Supply - 1",
        type: .supply,
        straightLengths: [10, 20, 25],
        groups: [
          .init(group: 1, letter: "a", value: 20),
          .init(group: 2, letter: "b", value: 15, quantity: 2),
          .init(group: 3, letter: "c", value: 10, quantity: 1),
        ],
        createdAt: Date(),
        updatedAt: Date()
      ),
      .init(
        id: UUID(1),
        projectID: UUID(0),
        name: "Test Return - 1",
        type: .return,
        straightLengths: [10, 20, 25],
        groups: [
          .init(group: 1, letter: "a", value: 20),
          .init(group: 2, letter: "b", value: 15, quantity: 2),
          .init(group: 3, letter: "c", value: 10, quantity: 1),
        ],
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

#endif
