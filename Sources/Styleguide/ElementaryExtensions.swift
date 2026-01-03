import Elementary
import ManualDCore

extension HTMLAttribute where Tag: HTMLTrait.Attributes.href {

  public static func href(route: SiteRoute.View) -> Self {
    href(SiteRoute.View.router.path(for: route))
  }
}
