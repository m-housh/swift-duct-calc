import Elementary
import Styleguide

// TODO: Need to add active to sidebar links.
struct Sidebar: HTML {

  var body: some HTML {
    aside(
      .class(
        """
        h-screen sticky top-0 min-w-[280px] flex-none border border-r-3 border-gray-800 bg-gray-100 shadow
        """
      )
    ) {
      row(title: "Project", icon: .mapPin, href: "/projects")
      row(title: "Rooms", icon: .doorClosed, href: "/rooms")
      row(title: "Equivalent Lengths", icon: .rulerDimensionLine, href: "#")
      row(title: "Friction Rate", icon: .squareFunction, href: "/friction-rate")
      row(title: "Duct Sizes", icon: .wind, href: "#")
    }
  }

  private func row(
    title: String,
    icon: Icon.Key,
    href: String
  ) -> some HTML {
    a(
      .class(
        """
        flex w-full items-center gap-4 text-gray-800 hover:bg-gray-300 px-4 py-2
        """
      ),
      .href(href)
    ) {
      Icon(icon)
      span(.class("text-xl font-bold")) {
        title
      }
    }
  }
}
