import ManualDCore

// Presentation ordering follows the relevant duct connection, not the overall
// artwork shape or an inferred descriptive name. Audit: docs/fitting-picker-duct-shapes.md.
extension Fitting.Definition {
  var pickerDuctShape: Fitting.Shape {
    switch groupID {
    case .supplyBranches:
      switch sourceCode?.rawValue {
      case "2A", "2B", "2C", "2I", "2J", "2K": .rectangular
      default: shape
      }
    case .supplyBoots:
      switch sourceCode?.rawValue {
      case "4G", "4H", "4I", "4J", "4K", "4L",
        "4Q", "4R", "4S", "4T", "4U", "4V", "4W", "4X", "4Y", "4Z",
        "4AA", "4AB", "4AC", "4AD", "4AE", "4AG", "4AJ", "4AK":
        .round
      case "4A", "4B", "4C", "4D", "4E", "4F", "4M", "4N", "4O", "4P",
        "4AF", "4AH", "4AI", "4AL", "4AM", "4AN", "4AO", "4AP", "4AQ", "4AR":
        .rectangular
      default: shape
      }
    default: shape
    }
  }
}
