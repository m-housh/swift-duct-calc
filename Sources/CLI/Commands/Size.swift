import ArgumentParser
import Dependencies
import ManualDClient

struct SizeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "size",
    abstract: "Calculate the required size of a duct."
  )

  @Option(
    name: .shortAndLong,
    help: "The design friction rate."
  )
  var frictionRate: Double = 0.06

  @Argument(
    help: "The required CFM for the duct."
  )
  var cfm: Int

  func run() async throws {
    @Dependency(\.manualD) var manualD

    let size = try await manualD.ductSize(cfm: cfm, frictionRate: frictionRate)
    print(
      """
      Calculated: \(size.calculatedSize.string(digits: 2))
      Final Size: \(size.finalSize)
      Flex Size: \(size.flexSize)
      """
    )

  }
}
