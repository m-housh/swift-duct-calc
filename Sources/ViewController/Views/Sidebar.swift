import Elementary

struct Sidebar: HTML {

  var body: some HTML {
    div(
      .class(
        """
          h-screen w-64 pt-10 border-r-3 border-gray-800 bg-gray-100 shadow
        """)
    ) {
      row(title: "Project", icon: "map-pin")
      row(title: "Rooms", icon: "door-closed")
      row(title: "Equivalent Lengths", icon: "ruler-dimension-line")
      row(title: "Friction Rate", icon: "square-function")
      row(title: "Duct Sizes", icon: "wind")
    }
  }

  private func row(
    title: String,
    icon: String
  ) -> some HTML {
    button(
      .class(
        """
        flex w-full items-center gap-4 text-gray-800 hover:bg-gray-300 pl-4 py-2
        """
      )
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
