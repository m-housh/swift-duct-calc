import Foundation
import ManualDCore

extension PdfClient.Request {

  func toMarkdown() -> String {
    var retval = """
      # Duct Calc

      **Name:** \(project.name)
      **Address:** \(project.streetAddress)
                 \(project.city), \(project.state) \(project.zipCode)

      ## Equipment

      |                 | Value                           |
      |:----------------|:--------------------------------|
      | Static Pressure | \(equipmentInfo.staticPressure.string()) |
      | Heating CFM     | \(equipmentInfo.heatingCFM.string())     | 
      | Cooling CFM     | \(equipmentInfo.coolingCFM.string())     | 

      ## Friction Rate

      | Component Loss  | Value                           |
      |:----------------|:--------------------------------|

      """
    for row in componentLosses {
      retval += "\(componentLossRow(row))\n"
    }

    retval += """


      | Results         | Value                           |
      |:-----------------|:---------------------------------|
      | Available Static Pressure    | \(frictionRate.availableStaticPressure.string()) |
      | Total Equivalent Length      | \(totalEquivalentLength.string())                |
      | Friction Rate Design Value   | \(frictionRate.value.string())                   |

      ## Duct Sizes

      | Register | Dsn CFM | Round Size | Velocity | Final Size | Flex Size | Height | Width |
      |:---------|:--------|:----------------|:---------|:-----------|:----------|:-------|:------|

      """
    for row in ductSizes.rooms {
      retval += "\(registerRow(row))\n"
    }

    retval += """

      ## Trunk Sizes

      ### Supply Trunks

      | Name     | Associated Supplies | Dsn CFM | Velocity | Final Size | Flex Size | Height | Width |
      |:---------|:--------------------|:--------|:---------|:-----------|:----------|:-------|:------|

      """
    for row in ductSizes.trunks.filter({ $0.type == .supply }) {
      retval += "\(trunkRow(row))\n"
    }

    retval += """

      ### Return Trunks / Run Outs

      | Name     | Associated Supplies | Dsn CFM | Velocity | Final Size | Flex Size | Height | Width |
      |:---------|:--------------------|:--------|:---------|:-----------|:----------|:-------|:------|

      """
    for row in ductSizes.trunks.filter({ $0.type == .return }) {
      retval += "\(trunkRow(row))\n"
    }

    return retval
  }

  func registerRow(_ row: DuctSizes.RoomContainer) -> String {
    return """
      | \(row.roomName) | \(row.designCFM.value.string(digits: 0)) | \(row.roundSize.string()) | \(row.velocity.string()) | \(row.finalSize.string()) | \(row.flexSize.string()) | \(row.height?.string() ?? "") | \(row.width?.string() ?? "") |
      """
  }

  func trunkRow(_ row: DuctSizes.TrunkContainer) -> String {
    return """
      | \(row.name ?? "") | \(associatedSupplyString(row)) | \(row.designCFM.value.string(digits: 0)) | \(row.roundSize.string()) | \(row.velocity.string()) | \(row.finalSize.string()) | \(row.flexSize.string()) | \(row.ductSize.height?.string() ?? "") | \(row.width?.string() ?? "") |
      """
  }

  func componentLossRow(_ row: ComponentPressureLoss) -> String {
    return """
      | \(row.name) | \(row.value.string()) |
      """
  }

  var totalEquivalentLength: Double {
    maxSupplyTEL.totalEquivalentLength + maxReturnTEL.totalEquivalentLength
  }

  func associatedSupplyString(_ row: DuctSizes.TrunkContainer) -> String {
    row.associatedSupplyString(rooms: ductSizes.rooms)
  }
}

extension DuctSizes.TrunkContainer {

  func associatedSupplyString(rooms: [DuctSizes.RoomContainer]) -> String {
    self.registerIDS(rooms: rooms)
      .joined(separator: ", ")
  }
}
