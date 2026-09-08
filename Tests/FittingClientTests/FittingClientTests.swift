import Dependencies
import FittingClient
import ManualDCore
import Testing

@Suite
struct FittingClientTests {
  let client = TemplateFittingClient.liveValue

  @Test
  func templateEvaluationUsesTheInjectedCurrentCatalog() async throws {
    var current = try await loadBundledFittingClient()
    let bridge = TemplateFittingClient.live(using: current)
    let result = try await bridge.evaluate(
      .init(type: .supply, fittingID: "8A-smooth", inputs: .sourceTable(choices: ["1", "90"])))
    guard case .resolved(let calculation) = result else {
      Issue.record("Expected current catalog calculation")
      return
    }
    #expect(
      calculation.catalogCalculation?.inputs == .roundElbow(radiusRatio: .one, angle: .degrees90))
    #expect(calculation.catalogCalculation?.catalogRevision == "fitting-catalog-v14")
    #expect(
      calculation.catalogCalculation?.equivalentLengthFeet == calculation.equivalentLengthFeet)
    current.evaluate = { _ in .unresolved([.init(.missingInput, field: .radiusRatio)]) }
    let unavailable = try await TemplateFittingClient.live(using: current).evaluate(
      .init(type: .supply, fittingID: "8A-smooth", inputs: .sourceTable(choices: ["1", "90"])))
    #expect(
      feet(unavailable) == nil,
      "The template adapter must not fall back to its old source table values")
  }

  @Test
  func catalogCoversAllGroupsAndPreservesSourceIdentity() async throws {
    let supply = try await client.fittings(.supply)
    let returns = try await client.fittings(.return)
    #expect(Set((supply + returns).map(\.id)).count == 231)
    #expect(Set(supply.map(\.group.rawValue)) == [1, 2, 3, 4, 8, 9, 11, 12])
    #expect(Set(returns.map(\.group.rawValue)) == [5, 6, 7, 8, 10, 11, 12])
    #expect(returns.first { $0.id == "5A-round" }?.sourceCode == "5B")
    #expect(returns.first { $0.id == "5C-round" }?.sourceCode == "5D")
    #expect(supply.first { $0.id == "11-junction-box" }?.sourceCode == nil)
  }

  @Test
  func bothStarterTemplatesUseSupportedChoicesAndDefaults() async throws {
    for configuration in starters {
      try await client.validateTemplate(configuration)
      let definitions = try await client.fittings(configuration.type)
      for choice in configuration.steps.flatMap(\.choices) {
        let definition = try #require(definitions.first { $0.id == choice.fittingID })
        #expect(definition.requirements.emptyInputs != nil)
      }
    }
  }

  @Test
  func reviewedElbowConstructionsAndFractionalMultiplier() async throws {
    let elbow = try await client.evaluate(
      .init(type: .supply, fittingID: "8A-4-or-5-piece", inputs: .sourceTable(choices: ["1"]))
    )
    #expect(feet(elbow) == 20)
    let elbow45 = try await client.evaluate(
      .init(type: .return, fittingID: "8A-3-piece-45", inputs: .fixed)
    )
    #expect(feet(elbow45) == 10)
    let smooth = try await client.evaluate(
      .init(type: .supply, fittingID: "8A-smooth", inputs: .sourceTable(choices: ["0.75", "20"]))
    )
    #expect(feet(smooth) == 6.2)
  }

  @Test
  func branchCountsUseExplicitInclusiveRange() async throws {
    for (count, expected) in [(0, 55.0), (1, 65.0), (4, 90.0), (5, 100.0), (25, 100.0)] {
      let result = try await client.evaluate(
        .init(type: .supply, fittingID: "2O", inputs: .downstreamBranches(count))
      )
      #expect(feet(result) == expected)
    }
    let blank = try await client.evaluate(
      .init(type: .supply, fittingID: "2O", inputs: .downstreamBranches(nil))
    )
    #expect(feet(blank) == nil)
  }

  @Test
  func missingUnsupportedAndIneligibleInputsRemainUnresolved() async throws {
    let requests: [TemplateFitting.EvaluationRequest] = [
      .init(type: .return, fittingID: "1A", inputs: .fixed),
      .init(type: .supply, fittingID: "3W", inputs: .fixed),
      .init(type: .supply, fittingID: "11-junction-box", inputs: .flexJunctionBox(.init())),
      .init(type: .supply, fittingID: "8A-4-or-5-piece", inputs: .sourceTable(choices: [nil])),
      .init(type: .supply, fittingID: "8A-smooth", inputs: .sourceTable(choices: ["1", "110"])),
      .init(
        type: .return, fittingID: "5H-rectangular",
        inputs: .dimensions(numeratorInches: 15, denominatorInches: 10)),
      .init(
        type: .return, fittingID: "5H-rectangular",
        inputs: .dimensions(numeratorInches: 10, denominatorInches: 0)),
      .init(type: .supply, fittingID: "2O", inputs: .downstreamBranches(-1)),
    ]
    for request in requests {
      let result = try await client.evaluate(request)
      #expect(feet(result) == nil)
    }
  }

  @Test
  func templateValidationUsesCatalogIdentityAndOptions() async throws {
    var configuration = starters[0]
    configuration.steps[0].choices = [.init(fittingID: "unknown")]
    await #expect(
      throws: TemplateFittingClient.TemplateValidationError.invalidFitting(
        section: configuration.steps[0].title,
        fittingID: configuration.steps[0].choices[0].fittingID)
    ) {
      try await client.validateTemplate(configuration)
    }
    configuration.steps[0].choices = [.init(fittingID: "6F")]
    await #expect(
      throws: TemplateFittingClient.TemplateValidationError.invalidFitting(
        section: configuration.steps[0].title,
        fittingID: configuration.steps[0].choices[0].fittingID)
    ) {
      try await client.validateTemplate(configuration)
    }
    configuration.steps[0].choices = [
      .init(fittingID: "1A", defaults: .sourceTable(choices: ["1"]))
    ]
    await #expect(
      throws: TemplateFittingClient.TemplateValidationError.invalidDefault(
        section: configuration.steps[0].title, fittingID: "1A")
    ) {
      try await client.validateTemplate(configuration)
    }
  }

  private func feet(_ evaluation: TemplateFitting.Evaluation) -> Double? {
    guard case .resolved(let calculation) = evaluation else { return nil }
    return calculation.equivalentLengthFeet
  }

  private var starters: [PathTemplate.Configuration] {
    withDependencies {
      $0.uuid = .incrementing
    } operation: {
      PathTemplate.starterConfigurations()
    }
  }
}
