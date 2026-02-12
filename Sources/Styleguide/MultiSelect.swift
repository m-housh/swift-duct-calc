import Elementary

extension HTMLTag {
  public enum daisyMultiSelect: HTMLTrait.Paired { public static let name = "daisy-multiselect" }
}
public typealias daisyMultiSelect<Content: HTML> = HTMLElement<HTMLTag.daisyMultiSelect, Content>

extension HTMLTrait.Attributes {
  public protocol chipStyle {}
  public protocol showSelectAll {}
  public protocol showClear {}
  public protocol virtualScroll {}
}

extension HTMLAttribute where Tag: HTMLTrait.Attributes.chipStyle {
  public static var chipStyle: Self {
    HTMLAttribute(name: "chip-style", value: nil)
  }
}

extension HTMLAttribute where Tag: HTMLTrait.Attributes.showSelectAll {
  public static var showSelectAll: Self {
    HTMLAttribute(name: "show-select-all", value: nil)
  }
}

extension HTMLAttribute where Tag: HTMLTrait.Attributes.showClear {
  public static var showClear: Self {
    HTMLAttribute(name: "show-clear", value: nil)
  }
}

extension HTMLAttribute where Tag: HTMLTrait.Attributes.virtualScroll {
  public static var virtualScroll: Self {
    HTMLAttribute(name: "virtual-scroll", value: nil)
  }
}

extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.required {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.disabled {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.placeholder {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.name {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.chipStyle {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.showSelectAll {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.showClear {}
extension HTMLTag.daisyMultiSelect: HTMLTrait.Attributes.virtualScroll {}
