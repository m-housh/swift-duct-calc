import Elementary

/// Reusable three-card looping selector. Its controller lives in group-carousel.js.
public struct GroupCarousel: HTML, Sendable {
  public struct Item: Sendable {
    public let id: Int
    public let title: String
    public let image: String?
    public let count: Int
    public init(id: Int, title: String, image: String?, count: Int) {
      self.id = id
      self.title = title
      self.image = image
      self.count = count
    }
  }
  let items: [Item]
  public init(items: [Item]) { self.items = items }
  public var body: some HTML {
    section(
      .class("group-carousel"), .init(name: "aria-roledescription", value: "carousel"),
      .init(name: "aria-label", value: "Fitting groups")
    ) {
      div(.class("carousel-controls")) {
        button(.type(.button), .data("carousel-step", value: "-1")) { "← Previous group" }
        span(.class("carousel-position"), .init(name: "role", value: "status")) {
          "1 of \(items.count) groups"
        }
        button(.type(.button), .data("carousel-step", value: "1")) { "Next group →" }
      }
      div(.class("carousel-track")) {
        for (index, item) in items.enumerated() {
          div(.class("carousel-slide"), .data("carousel-index", value: String(index))) {
            div(.class("group-option")) {
              button(
                .type(.button), .class("group-card"), .data("choose-group", value: String(item.id))
              ) {
                if let image = item.image {
                  img(
                    .src(image), .alt("Group \(item.id): \(item.title)"),
                    .init(name: "draggable", value: "false"))
                }
                span {
                  "Group \(item.id) · \(item.title)"
                  small { "\(item.count) fitting choices" }
                }
              }
              div(.class("group-path-state"), .data("group-state", value: String(item.id))) {
                "None in this path"
              }
            }
            button(
              .type(.button), .class("carousel-peek"), .data("carousel-jump", value: String(index)),
              .init(name: "aria-label", value: "Bring Group \(item.id) to front")
            ) {}
          }
        }
      }
      div(.class("carousel-pagination"), .init(name: "aria-label", value: "Jump to group")) {
        for (index, item) in items.enumerated() {
          button(
            .type(.button), .data("carousel-jump", value: String(index)),
            .init(name: "aria-label", value: "Show Group \(item.id): \(item.title)")
          ) { "\(item.id)" }
        }
      }
      p(.class("carousel-hint")) {
        "Swipe or drag in either direction · Select the front card to choose a group"
      }
    }
  }
}

public struct PickerDialog<Inner: HTML & Sendable>: HTML, Sendable {
  let id: String
  let title: String
  let inner: Inner
  public init(id: String, title: String, @HTMLBuilder content: () -> Inner) {
    self.id = id
    self.title = title
    self.inner = content()
  }
  public var body: some HTML<HTMLTag.dialog> {
    dialog(
      .id(id), .class("path-picker-dialog"), .init(name: "aria-labelledby", value: "\(id)-title")
    ) {
      div(.class("picker-top")) {
        h2(.id("\(id)-title")) { title }
        button(.type(.button), .data("close-dialog", value: id)) { "Close" }
      }
      inner
    }
  }
}
