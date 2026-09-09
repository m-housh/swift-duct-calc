import DatabaseClient
import ManualDCore

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepThree {

  func validate() throws(ValidationError) {
    guard groupGroups.count == groupLengths.count,
      groupGroups.count == groupLetters.count,
      groupGroups.count == groupQuantities.count
    else {
      throw ValidationError("Equivalent length form group counts are not equal.")
    }
    guard groupLengths.allSatisfy({ $0.isFinite && $0 > 0 }) else {
      throw ValidationError("Fitting lengths must be finite numbers greater than zero.")
    }
  }

  var groups: [EquivalentLength.FittingGroup] {
    var groups = [EquivalentLength.FittingGroup]()
    for (n, group) in groupGroups.enumerated() {
      groups.append(
        .init(
          group: group,
          letter: groupLetters[n],
          value: groupLengths[n],
          quantity: groupQuantities[n]
        )
      )
    }
    return groups

  }
}

extension EquivalentLength.Create {

  init(
    form: SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepThree,
    projectID: Project.ID
  ) throws {
    try form.validate()
    self.init(
      projectID: projectID,
      name: form.name,
      type: form.type,
      straightLengths: form.straightLengths,
      groups: form.groups
    )
  }
}

extension EquivalentLength.Update {
  init(
    form: SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepThree,
    projectID: Project.ID
  ) throws {
    try form.validate()
    self.init(
      name: form.name,
      type: form.type,
      straightLengths: form.straightLengths,
      groups: form.groups
    )
  }
}
