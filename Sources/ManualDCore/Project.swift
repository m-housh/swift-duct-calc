import Dependencies
import Foundation

public struct Project: Codable, Equatable, Identifiable, Sendable {

  public let id: UUID
  public let name: String
  public let streetAddress: String
  public let city: String
  public let state: String
  public let zipCode: String
  public let sensibleHeatRatio: Double?
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    name: String,
    streetAddress: String,
    city: String,
    state: String,
    zipCode: String,
    sensibleHeatRatio: Double? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.streetAddress = streetAddress
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.sensibleHeatRatio = sensibleHeatRatio
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Project {

  public struct Create: Codable, Equatable, Sendable {

    public let name: String
    public let streetAddress: String
    public let city: String
    public let state: String
    public let zipCode: String
    public let sensibleHeatRatio: Double?

    public init(
      name: String,
      streetAddress: String,
      city: String,
      state: String,
      zipCode: String,
      sensibleHeatRatio: Double? = nil,
    ) {
      self.name = name
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
      self.sensibleHeatRatio = sensibleHeatRatio
    }
  }

  public struct CompletedSteps: Codable, Equatable, Sendable {

    public let equipmentInfo: Bool
    public let rooms: Bool
    public let equivalentLength: Bool
    public let frictionRate: Bool

    public init(
      equipmentInfo: Bool,
      rooms: Bool,
      equivalentLength: Bool,
      frictionRate: Bool
    ) {
      self.equipmentInfo = equipmentInfo
      self.rooms = rooms
      self.equivalentLength = equivalentLength
      self.frictionRate = frictionRate
    }
  }

  public struct Detail: Codable, Equatable, Sendable {

    public let project: Project
    public let componentLosses: [ComponentPressureLoss]
    public let equipmentInfo: EquipmentInfo
    public let equivalentLengths: [EffectiveLength]
    public let rooms: [Room]
    public let trunks: [TrunkSize]

    public init(
      project: Project,
      componentLosses: [ComponentPressureLoss],
      equipmentInfo: EquipmentInfo,
      equivalentLengths: [EffectiveLength],
      rooms: [Room],
      trunks: [TrunkSize]
    ) {
      self.project = project
      self.componentLosses = componentLosses
      self.equipmentInfo = equipmentInfo
      self.equivalentLengths = equivalentLengths
      self.rooms = rooms
      self.trunks = trunks
    }
  }

  public struct Update: Codable, Equatable, Sendable {

    public let name: String?
    public let streetAddress: String?
    public let city: String?
    public let state: String?
    public let zipCode: String?
    public let sensibleHeatRatio: Double?

    public init(
      name: String? = nil,
      streetAddress: String? = nil,
      city: String? = nil,
      state: String? = nil,
      zipCode: String? = nil,
      sensibleHeatRatio: Double? = nil
    ) {
      self.name = name
      self.streetAddress = streetAddress
      self.city = city
      self.state = state
      self.zipCode = zipCode
      self.sensibleHeatRatio = sensibleHeatRatio
    }
  }
}

#if DEBUG

  extension Project {

    public static var mock: Self {
      @Dependency(\.uuid) var uuid
      @Dependency(\.date.now) var now

      return .init(
        id: uuid(),
        name: "Testy McTestface",
        streetAddress: "1234 Sesame Street",
        city: "Monroe",
        state: "OH",
        zipCode: "55555",
        createdAt: now,
        updatedAt: now
      )
    }
  }

#endif
