import Elementary

public struct LabeledContent<Label: HTML, Content: HTML>: HTML {
  let label: @Sendable () -> Label
  let content: @Sendable () -> Content
  let position: LabelPosition

  public init(
    position: LabelPosition = .default,
    @HTMLBuilder label: @escaping @Sendable () -> Label,
    @HTMLBuilder content: @escaping @Sendable () -> Content
  ) {
    self.position = position
    self.label = label
    self.content = content
  }

  public var body: some HTML<HTMLTag.div> {
    div {
      switch position {
      case .leading:
        label()
        content()
      case .trailing:
        content()
        label()
      case .top:
        label()
        content()
      case .bottom:
        content()
        label()
      }
    }
    .attributes(.class("flex space-x-4"), when: position.isHorizontal)
    .attributes(.class("space-y-4"), when: position.isVertical)
  }
}

// TODO: Merge / use TooltipPosition
public enum LabelPosition: String, CaseIterable, Equatable, Sendable {
  case leading
  case trailing
  case top
  case bottom

  var isHorizontal: Bool {
    self == .leading || self == .trailing
  }

  var isVertical: Bool {
    self == .top || self == .bottom
  }

  public static let `default` = Self.leading
}

extension LabeledContent: Sendable where Label: Sendable, Content: Sendable {}

extension LabeledContent where Label == Styleguide.Label {

  public init(
    _ label: String, position: LabelPosition = .default,
    @HTMLBuilder content: @escaping @Sendable () -> Content
  ) {
    self.init(
      position: position,
      label: { Label(label) },
      content: content
    )
  }
}
