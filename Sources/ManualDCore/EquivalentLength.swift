import Dependencies
import Foundation

// TODO: Not sure how to model effective length groups in the database.
//       thinking perhaps just have a 'data' field that encoded / decodes
//       to swift types??
public struct EquivalentLength: Codable, Equatable, Identifiable, Sendable {

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
    type: EquivalentLength.EffectiveLengthType,
    straightLengths: [Int],
    groups: [EquivalentLength.Group],
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

extension EquivalentLength {

  public struct Create: Codable, Equatable, Sendable {

    public let projectID: Project.ID
    public let name: String
    public let type: EffectiveLengthType
    public let straightLengths: [Int]
    public let groups: [Group]

    public init(
      projectID: Project.ID,
      name: String,
      type: EquivalentLength.EffectiveLengthType,
      straightLengths: [Int],
      groups: [EquivalentLength.Group]
    ) {
      self.projectID = projectID
      self.name = name
      self.type = type
      self.straightLengths = straightLengths
      self.groups = groups
    }
  }

  public struct Update: Codable, Equatable, Sendable {

    public let name: String?
    public let type: EffectiveLengthType?
    public let straightLengths: [Int]?
    public let groups: [Group]?

    public init(
      name: String? = nil,
      type: EquivalentLength.EffectiveLengthType? = nil,
      straightLengths: [Int]? = nil,
      groups: [EquivalentLength.Group]? = nil
    ) {
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

  public struct MaxContainer: Codable, Equatable, Sendable {
    public let supply: EquivalentLength?
    public let `return`: EquivalentLength?

    public var total: Double? {
      guard let supply else { return nil }
      guard let `return` else { return nil }
      return supply.totalEquivalentLength + `return`.totalEquivalentLength
    }

    public init(supply: EquivalentLength? = nil, return: EquivalentLength? = nil) {
      self.supply = supply
      self.return = `return`
    }
  }
}

extension EquivalentLength {
  public var totalEquivalentLength: Double {
    straightLengths.reduce(into: 0.0) { $0 += Double($1) }
      + groups.totalEquivalentLength
  }
}

extension Array where Element == EquivalentLength.Group {

  public var totalEquivalentLength: Double {
    reduce(into: 0.0) {
      $0 += ($1.value * Double($1.quantity))
    }
  }
}

#if DEBUG

  extension EquivalentLength {

    public static func mock(projectID: Project.ID) -> [Self] {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return [
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Supply - 1",
          type: .supply,
          straightLengths: [10, 25],
          groups: [
            .init(group: 1, letter: "a", value: 20),
            .init(group: 2, letter: "b", value: 30, quantity: 1),
            .init(group: 3, letter: "a", value: 10, quantity: 1),
            .init(group: 12, letter: "a", value: 10, quantity: 1),
          ],
          createdAt: now,
          updatedAt: now
        ),
        .init(
          id: uuid(),
          projectID: projectID,
          name: "Return - 1",
          type: .return,
          straightLengths: [10, 20, 5],
          groups: [
            .init(group: 5, letter: "a", value: 10),
            .init(group: 6, letter: "a", value: 15, quantity: 1),
            .init(group: 7, letter: "a", value: 20, quantity: 1),
          ],
          createdAt: now,
          updatedAt: now
        ),
      ]
    }

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
