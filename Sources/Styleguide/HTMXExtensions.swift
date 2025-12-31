import Elementary
import ElementaryHTMX
import ManualDCore

extension HTMLAttribute.hx {
  @Sendable
  public static func get(route: SiteRoute.View) -> HTMLAttribute {
    get(SiteRoute.View.router.path(for: route))
  }

  @Sendable
  public static func patch(route: SiteRoute.View) -> HTMLAttribute {
    patch(SiteRoute.View.router.path(for: route))
  }

  @Sendable
  public static func post(route: SiteRoute.View) -> HTMLAttribute {
    post(SiteRoute.View.router.path(for: route))
  }

  @Sendable
  public static func put(route: SiteRoute.View) -> HTMLAttribute {
    put(SiteRoute.View.router.path(for: route))
  }

  // @Sendable
  // static func delete(route: SiteRoute.Api) -> HTMLAttribute {
  //   delete(SiteRoute.Api.router.path(for: route))
  // }
}
