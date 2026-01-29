import Dependencies
import Foundation

/// Represents a single duct design project / system.
///
/// Holds items such as project name and address.
public struct Project: Codable, Equatable, Identifiable, Sendable {
  /// The unique ID of the project.
  public let id: UUID
  /// The name of the project.
  public let name: String
  /// The street address of the project.
  public let streetAddress: String
  /// The city of the project.
  public let city: String
  /// The state of the project.
  public let state: String
  /// The zip code of the project.
  public let zipCode: String
  /// The global sensible heat ratio for the project.
  ///
  /// **NOTE:** This is used for calculating the sensible cooling load for rooms.
  public let sensibleHeatRatio: Double?
  /// When the project was created in the database.
  public let createdAt: Date
  /// When the project was updated in the database.
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
  /// Represents the data needed to create a new project.
  public struct Create: Codable, Equatable, Sendable {

    /// The name of the project.
    public let name: String
    /// The street address of the project.
    public let streetAddress: String
    /// The city of the project.
    public let city: String
    /// The state of the project.
    public let state: String
    /// The zip code of the project.
    public let zipCode: String
    /// The global sensible heat ratio for the project.
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

  /// Represents steps that are completed in order to calculate the duct sizes
  /// for a project.
  ///
  /// This is primarily used on the web pages to display errors or color of the
  /// different steps of a project.
  public struct CompletedSteps: Codable, Equatable, Sendable {
    /// Whether there is ``EquipmentInfo`` for a project.
    public let equipmentInfo: Bool
    /// Whether there are ``Room``'s for a project.
    public let rooms: Bool
    /// Whether there are ``EquivalentLength``'s for a project.
    public let equivalentLength: Bool
    /// Whether there is a ``FrictionRate`` for a project.
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

  /// Represents project details loaded from the database.
  ///
  /// This is generally used to perform duct sizing calculations for the
  /// project, once all the steps have been completed.
  public struct Detail: Codable, Equatable, Sendable {

    /// The project.
    public let project: Project
    /// The component pressure losses for the project.
    public let componentLosses: [ComponentPressureLoss]
    /// The equipment info for the project.
    public let equipmentInfo: EquipmentInfo
    /// The equivalent lengths for the project.
    public let equivalentLengths: [EquivalentLength]
    /// The rooms in the project.
    public let rooms: [Room]
    /// The trunk sizes in the project.
    public let trunks: [TrunkSize]

    public init(
      project: Project,
      componentLosses: [ComponentPressureLoss],
      equipmentInfo: EquipmentInfo,
      equivalentLengths: [EquivalentLength],
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

  /// Represents fields that can be updated for a project that has already been created.
  ///
  /// Only fields that are supplied get updated in the database.
  public struct Update: Codable, Equatable, Sendable {

    /// The name of the project.
    public let name: String?
    /// The street address of the project.
    public let streetAddress: String?
    /// The city of the project.
    public let city: String?
    /// The state of the project.
    public let state: String?
    /// The zip code of the project.
    public let zipCode: String?
    /// The global sensible heat ratio for the project.
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
