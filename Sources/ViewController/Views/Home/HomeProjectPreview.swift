import Elementary
import ManualDCore

struct HomeProjectPreview: HTML, Sendable {
  var body: some HTML {
    section(.class("workspace-demo"), .custom(name: "aria-label", value: "Project preview with sample data")) {
      div(.class("demo-top")) {
        span { "PROJECT PREVIEW" }
        span { "Sample data · Maple Avenue" }
        button(.type(.button), .class("demo-playback"), .disabled) { "Play preview" }
      }
      div(.class("demo-stage")) {
        for (index, step) in HomePreviewStep.allCases.enumerated() {
          div(
            .class("demo-panel"), .id("preview-panel-\(index)"),
            .custom(name: "data-preview-panel", value: String(index)),
            .custom(name: "aria-hidden", value: index == 0 ? "false" : "true")
          ) {
            iframe(
              .class("demo-app-frame"), .title("\(step.title) · sample project"), .tabindex(-1),
              .custom(name: "sandbox", value: "allow-same-origin"),
              .custom(name: "loading", value: "lazy"),
              .src(SiteRoute.View.router.path(for: .homePreview(step)))
            ) {}
          }
        }
      }
      nav(.class("demo-steps"), .custom(name: "aria-label", value: "Preview steps")) {
        for (index, step) in HomePreviewStep.allCases.enumerated() {
          button(
            .type(.button), .disabled,
            .custom(name: "data-preview-step", value: String(index)),
            .custom(name: "aria-controls", value: "preview-panel-\(index)"),
            .custom(name: "aria-pressed", value: index == 0 ? "true" : "false")
          ) {
            small { "0\(index + 1)" }
            span { step.title }
          }
        }
      }
    }
  }
}
