import Elementary

struct Sidebar: HTML {

  var body: some HTML {
    div(
      .class(
        """
          h-screen w-64 border-r-3 bg-gray-100 shadow space-y-4
        """)
    ) {
      row(title: "Project", icon: "map-pin")
      row(title: "Rooms", icon: "door-closed")
      row(title: "Equivalent Lengths", icon: "ruler-dimension-line")
      row(title: "Friction Rate", icon: "square-function")
      row(title: "Duct Sizes", icon: "wind")
    }
  }

  func row(
    title: String,
    icon: String
  ) -> some HTML {
    button(
      .class(
        """
        flex w-full jusitfy-between items-center text-gray-800 hover:bg-gray-300
        """
      )
    ) {
      i(.data("lucide", value: icon)) {}
      p(
        .class("text-2xl flex-1")
      ) {
        title
      }
    }
  }
}
