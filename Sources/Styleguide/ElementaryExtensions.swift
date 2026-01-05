import Elementary
import ManualDCore

extension HTMLAttribute where Tag: HTMLTrait.Attributes.href {

  public static func href(route: SiteRoute.View) -> Self {
    href(SiteRoute.View.router.path(for: route))
  }
}

extension HTMLAttribute where Tag == HTMLTag.form {

  public static func action(route: SiteRoute.View) -> Self {
    action(SiteRoute.View.router.path(for: route))
  }
}

extension HTMLAttribute where Tag == HTMLTag.input {

  public static func value(_ string: String?) -> Self {
    value(string ?? "")
  }

  public static func value(_ int: Int?) -> Self {
    value(int == nil ? "" : "\(int!)")
  }

  public static func value(_ double: Double?) -> Self {
    value(double == nil ? "" : "\(double!)")
  }
}
