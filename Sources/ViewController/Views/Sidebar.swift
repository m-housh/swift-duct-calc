import Elementary

struct Sidebar: HTML {

  var body: some HTML {
    aside(
      .class(
        """
        h-screen sticky top-0 border-r-3 border-gray-800 bg-gray-100 shadow
        """
      )
    ) {
      row(title: "Project", icon: "map-pin", href: "/projects")
      row(title: "Rooms", icon: "door-closed", href: "/rooms")
      row(title: "Equivalent Lengths", icon: "ruler-dimension-line", href: "#")
      row(title: "Friction Rate", icon: "square-function", href: "#")
      row(title: "Duct Sizes", icon: "wind", href: "#")
    }
  }

  private func row(
    title: String,
    icon: String,
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
      i(.data("lucide", value: icon)) {}
      p(
        .class("text-xl font-bold")
      ) {
        title
      }
    }
  }
}
