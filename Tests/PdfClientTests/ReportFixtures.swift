import Dependencies
import Foundation
import ManualDCore
import PdfClient

let reportDate = Date(timeIntervalSince1970: 1_234_567_890)

func reportFixture(large: Bool = false, empty: Bool = false, invalid: Bool = false)
  -> PdfClient.Request
{
  @Dependency(\.uuid) var uuid
  let project = Project(
    id: uuid(),
    name: large
      ? "Maple House & Annex <West> with a long project name for pagination and footer wrapping"
      : "Maple House",
    streetAddress: "1234 Maple Lane", city: "Monroe", state: "OH", zipCode: "45050",
    createdAt: reportDate, updatedAt: reportDate)
  let base = PdfClient.Request.mock(project: project)
  let rooms =
    empty
    ? []
    : large
      ? (1...75).map { index in
        Room(
          id: uuid(), projectID: project.id, name: "Room \(index)", heatingLoad: 2_000,
          coolingLoad: .init(total: 1_000), createdAt: reportDate, updatedAt: reportDate)
      } : base.rooms
  let sizes: [DuctSizes.RoomContainer] =
    large
    ? rooms.map { room in
      .init(
        roomID: room.id, roomName: room.name, roomLevel: nil, roomRegister: 1,
        heatingLoad: 2_000, coolingLoad: 830, heatingCFM: 75, coolingCFM: 85,
        ductSize: .init(
          designCFM: .cooling(85), roundSize: 7.2, finalSize: 8, velocity: 244,
          flexSize: 9, height: 6, width: 8))
    }
    : empty
      ? []
      : base.ductSizes.rooms.enumerated().map { index, row in
        let height: Int? = [0: 4, 3: 6, 7: 8][index]
        return .init(
          roomID: row.roomID, roomName: row.roomName, roomLevel: row.roomLevel,
          roomRegister: row.roomRegister, heatingLoad: row.heatingLoad,
          coolingLoad: row.coolingLoad,
          heatingCFM: row.heatingCFM, coolingCFM: row.coolingCFM,
          ductSize: .init(
            designCFM: row.designCFM, roundSize: 7.2, finalSize: 8,
            velocity: row.velocity, flexSize: 9, height: height,
            width: height.map { Int((Double.pi * 16 / Double($0)).rounded()) }))
      }
  let trunks: [DuctSizes.TrunkContainer] =
    empty
    ? []
    : large
      ? (1...55).map { index in
        .init(
          trunk: .init(
            id: uuid(), projectID: project.id, type: index.isMultiple(of: 2) ? .return : .supply,
            rooms: [], name: "Branch \(index)"),
          ductSize: .init(
            designCFM: .cooling(1_000), roundSize: 18.4, finalSize: 20, velocity: 459,
            flexSize: 22, height: 10, width: 31))
      }
      : base.ductSizes.trunks.enumerated().map { index, row in
        let height = index == 0 ? 10 : 14
        return .init(
          trunk: row.trunk,
          ductSize: .init(
            designCFM: row.designCFM, roundSize: 18.4, finalSize: 20, velocity: row.velocity,
            flexSize: 22, height: height, width: Int((Double.pi * 100 / Double(height)).rounded())))
      }
  let supply =
    large
    ? EquivalentLength(
      id: uuid(), projectID: project.id, name: "Extended supply path", type: .supply,
      straightLengths: Array(repeating: 10, count: 30),
      groups: (1...100).map { .init(group: $0, letter: "a", value: 1.25, quantity: 2) },
      createdAt: reportDate, updatedAt: reportDate) : base.maxSupplyTEL
  let losses =
    large
    ? (1...30).map { index in
      ComponentPressureLoss(
        id: uuid(), projectID: project.id, name: "Component \(index)", value: 0.01,
        createdAt: reportDate, updatedAt: reportDate)
    } : base.componentLosses
  let available = base.equipmentInfo.staticPressure - losses.reduce(0) { $0 + $1.value }
  return .init(
    project: project, rooms: rooms, componentLosses: losses,
    ductSizes: .init(rooms: sizes, trunks: trunks), equipmentInfo: base.equipmentInfo,
    maxSupplyTEL: supply, maxReturnTEL: base.maxReturnTEL,
    frictionRate: .init(
      availableStaticPressure: available,
      value: invalid
        ? 0.019
        : available * 100 / (supply.totalEquivalentLength + base.maxReturnTEL.totalEquivalentLength)
    ),
    projectSHR: base.projectSHR)
}
