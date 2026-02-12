import ManualDCore

extension Project.Detail {
  var maxContainer: EquivalentLength.MaxContainer {
    .init(
      supply: equivalentLengths.filter({ $0.type == .supply })
        .sorted(by: { $0.totalEquivalentLength > $1.totalEquivalentLength })
        .first,
      return: equivalentLengths.filter({ $0.type == .return })
        .sorted(by: { $0.totalEquivalentLength > $1.totalEquivalentLength })
        .first
    )
  }
}
