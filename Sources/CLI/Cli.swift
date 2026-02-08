import ArgumentParser

@main
struct DuctCalcCli: AsyncParsableCommand {
  static let configuration: CommandConfiguration = .init(
    commandName: "ductcalc",
    abstract: "Perform duct calculations.",
    subcommands: [
      ConvertCommand.self,
      SizeCommand.self,
    ],
    defaultSubcommand: SizeCommand.self
  )
}
