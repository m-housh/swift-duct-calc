import Elementary

public struct DesignMetric: HTML, Sendable {
  let label: String
  let value: String
  let unit: String
  let error: String?
  public init(_ label: String, value: String, unit: String = "", error: String? = nil) {
    self.label = label
    self.value = value
    self.unit = unit
    self.error = error
  }
  public var body: some HTML {
    div(.class(error == nil ? "design-metric" : "design-metric invalid-metric")) {
      span { label }
      strong {
        value
        small { unit }
      }
      if let error { p(.class("metric-error"), .role("alert")) { error } }
    }
  }
}

public struct ProjectHouse: HTML, Sendable {
  public init() {}
  public var body: some HTML {
    HTMLRaw(
      """
      <svg class="project-house-art" viewBox="0 0 360 320" preserveAspectRatio="none" aria-hidden="true">
      <path class="house-chimney" d="M270 106V76L288 66H316V144Z"/>
      <path class="house-chimney-side" d="M270 106V76L288 66V122Z"/>
      <path class="house-ground" d="M12 150L180 8L348 150V310H12Z"/>
      <path class="house-front" d="M12 150L132 49C185 101 208 156 225 198V310H12Z"/>
      <path class="house-roof-sweep" d="M140 42L180 8L348 150V252C284 237 249 211 228 180C199 120 182 83 140 42Z"/>
      <path class="house-warm-corner" d="M236 213C264 244 304 261 348 272V310H236Z"/>
      </svg>
      """)
  }
}
