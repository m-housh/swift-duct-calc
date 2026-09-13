import Foundation
import ManualDCore

/// One deterministic, in-memory project for the landing preview. Nothing is stored in the database.
enum HomePreviewData {
  private static let date = Date(timeIntervalSince1970: 1_709_251_200)
  static let project = Project(
    id: UUID(9000), name: "Maple Avenue", streetAddress: "24 Maple Avenue",
    city: "Columbus", state: "OH", zipCode: "43215", sensibleHeatRatio: 0.83,
    createdAt: date, updatedAt: date)
  static let equipment = EquipmentInfo(
    id: UUID(9001), projectID: project.id, staticPressure: 0.5,
    heatingCFM: 1200, coolingCFM: 1200, createdAt: date, updatedAt: date)

  private static let roomSpecs: [(name: String, airflow: Double, registers: Int, size: Int)] = [
    ("Living room", 300, 2, 7), ("Kitchen", 150, 1, 7),
    ("Primary bedroom", 240, 1, 9), ("Bedroom 2", 180, 1, 8),
    ("Dining room", 180, 1, 8), ("Study", 150, 1, 7),
  ]
  static let rooms: [Room] = roomSpecs.enumerated().map { index, spec in
    Room(
      id: UUID(9010 + index), projectID: project.id, name: spec.name,
      heatingLoad: spec.airflow * 50, coolingLoad: .init(total: spec.airflow * 25),
      registerCount: spec.registers, createdAt: date, updatedAt: date)
  }
  static let paths: [EquivalentLength] = [
    .init(
      id: UUID(9020), projectID: project.id, name: "Primary bedroom supply", type: .supply,
      straightLengths: [20, 10],
      groups: [.init(group: 1, letter: "A", value: 35), .init(group: 8, letter: "A", value: 70, quantity: 2)],
      createdAt: date, updatedAt: date),
    .init(
      id: UUID(9021), projectID: project.id, name: "Hall return", type: .return,
      straightLengths: [15], groups: [.init(group: 5, letter: "A", value: 80)],
      createdAt: date, updatedAt: date),
  ]
  static let losses: [ComponentPressureLoss] = [
    ("Filter", 0.10), ("Coil", 0.11), ("Supply outlet", 0.03),
    ("Return grille", 0.03), ("Balancing damper", 0.03),
  ].enumerated().map { index, loss in
    .init(id: UUID(9030 + index), projectID: project.id, name: loss.0, value: loss.1,
          createdAt: date, updatedAt: date)
  }
  static let frictionRate = FrictionRate(availableStaticPressure: 0.20, value: 0.20 / 300 * 100)

  static let ductSizes = DuctSizes(
    rooms: roomSpecs.enumerated().flatMap { index, spec in
      (1...spec.registers).map { register in
        let airflow = spec.airflow / Double(spec.registers)
        return DuctSizes.RoomContainer(
          roomID: rooms[index].id, roomName: spec.name, roomLevel: nil, roomRegister: register,
          heatingLoad: airflow * 50, coolingLoad: airflow * 25 * 0.83,
          heatingCFM: airflow, coolingCFM: airflow,
          ductSize: size(airflow: airflow, diameter: spec.size))
      }
    },
    trunks: [TrunkSize.TrunkType.supply, .return].enumerated().map { index, type in
      .init(
        trunk: .init(
          id: UUID(9040 + index), projectID: project.id, type: type,
          rooms: rooms.map { .init(room: $0, registers: Array(1...$0.registerCount)) },
          name: type == .supply ? "Main supply" : "Main return"),
        ductSize: size(airflow: 1200, diameter: 16))
    })

  private static func size(airflow: Double, diameter: Int) -> DuctSizes.SizeContainer {
    .init(
      designCFM: .cooling(airflow), roundSize: Double(diameter), finalSize: diameter,
      velocity: Int(airflow / (.pi * pow(Double(diameter) / 24, 2))), flexSize: diameter + 1)
  }
}
