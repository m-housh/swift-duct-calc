import ArgumentParser
import Dependencies
import ManualDClient

struct ConvertCommand: AsyncParsableCommand {

  static let configuration = CommandConfiguration(
    commandName: "convert",
    abstract: "Convert to an equivalent recangular size."
  )

  @Option(
    name: .shortAndLong,
    help: "The height"
  )
  var height: Int

  @Argument(
    // name: .shortAndLong,
    help: "The round size."
  )
  var roundSize: Int

  func run() async throws {
    @Dependency(\.manualD) var manualD

    let size = try await manualD.rectangularSize(
      round: .init(roundSize),
      height: .init(height)
    )

    print("\(size.width) x \(height)")
  }

}
