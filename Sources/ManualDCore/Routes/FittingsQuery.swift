extension SiteRoute.View {
  /// Shareable reference state. These fields select presentation, never authentication.
  public struct FittingsQuery: Equatable, Sendable {
    public var system: String?
    public var group: String?
    public var fitting: String?
    public var q: String?
    public var type: String?
    public var data: String?

    public init(
      system: String? = nil,
      group: String? = nil,
      fitting: String? = nil,
      q: String? = nil,
      type: String? = nil,
      data: String? = nil
    ) {
      self.system = system
      self.group = group
      self.fitting = fitting
      self.q = q
      self.type = type
      self.data = data
    }
  }
}
