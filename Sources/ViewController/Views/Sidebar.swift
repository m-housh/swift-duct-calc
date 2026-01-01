import Elementary
import Styleguide

// TODO: Need to add active to sidebar links.
struct Sidebar: HTML {

  var body: some HTML {
    aside(
      .class(
        """
        h-screen sticky top-0 max-w-[280px] flex-none 
        border-r-2 border-gray-200 
        shadow-lg
        """
      )
    ) {
      row(title: "Project", icon: .mapPin, href: "/projects")
      row(title: "Rooms", icon: .doorClosed, href: "/rooms")
      row(title: "Equivalent Lengths", icon: .rulerDimensionLine, href: "/effective-lengths")
      row(title: "Friction Rate", icon: .squareFunction, href: "/friction-rate")
        .attributes(.data("active", value: "true"))
      row(title: "Duct Sizes", icon: .wind, href: "#")
    }
  }

  // TODO: Use SiteRoute.View routes as href.
  private func row(
    title: String,
    icon: Icon.Key,
    href: String
  ) -> some HTML<HTMLTag.a> {
    a(
      .class(
        """
        flex w-full items-center gap-4
        hover:bg-gray-300 hover:text-gray-800
        data-[active=true]:bg-gray-300 data-[active=true]:text-gray-800
        px-4 py-2
        """
      ),
      .href(href)
    ) {
      Icon(icon)
      span(.class("text-xl")) {
        title
      }
    }
  }
}
