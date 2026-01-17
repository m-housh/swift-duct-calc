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
      |-----------------|---------------------------------|
      | Static Pressure | \(equipmentInfo.staticPressure) |
      | Heating CFM     | \(equipmentInfo.heatingCFM)     | 
      | Cooling CFM     | \(equipmentInfo.coolingCFM)     | 

      ## Friction Rate

      |                 | Value                           |
      |-----------------|---------------------------------|

      """
    for row in componentLosses {
      retval = """
        \(retval)
        \(componentLossRow(row))
        """
    }

    return retval
  }

  func componentLossRow(_ row: ComponentPressureLoss) -> String {
    return """
      | \(row.name) | \(row.value) |
      """
  }
}
