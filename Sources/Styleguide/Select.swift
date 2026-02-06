import Elementary
import Foundation

/// NOTE: This does not have the 'select' class added to it, because it's generally
///       added to the label of the field.
public struct Select<Label, Element>: HTML where Label: HTML {

  let label: @Sendable (Element) -> Label
  let value: @Sendable (Element) -> String
  let selected: @Sendable (Element) -> Bool
  let items: [Element]
  let placeholder: String?

  public init(
    _ items: [Element],
    placeholder: String? = nil,
    value: @escaping @Sendable (Element) -> String,
    selected: @escaping @Sendable (Element) -> Bool = { _ in false },
    @HTMLBuilder label: @escaping @Sendable (Element) -> Label
  ) {
    self.label = label
    self.items = items
    self.placeholder = placeholder
    self.selected = selected
    self.value = value
  }

  public var body: some HTML<HTMLTag.select> {
    select {
      if let placeholder {
        option(.selected, .disabled) { placeholder }
      }
      for item in items {
        option(.value(value(item))) { label(item) }
          .attributes(.selected, when: selected(item))
      }
    }
  }
}

extension Select: Sendable where Element: Sendable, Label: Sendable {}

extension Select where Element: Identifiable, Element.ID == UUID, Element: Sendable {

  public init(
    _ items: [Element],
    placeholder: String? = nil,
    selected: @escaping @Sendable (Element) -> Bool = { _ in false },
    @HTMLBuilder label: @escaping @Sendable (Element) -> Label
  ) {
    self.init(
      items,
      placeholder: placeholder,
      value: { $0.id.uuidString },
      selected: selected,
      label: label
    )

  }

}
