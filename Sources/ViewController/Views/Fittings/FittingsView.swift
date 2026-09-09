import Elementary
import ManualDCore
import Styleguide

/// The public reference shares one document with its signed-in data inspector.
struct FittingsView: HTML, Sendable {
  let isLoggedIn: Bool

  var body: some HTML {
    Navbar(showFittingsButton: false, showSidebarToggle: false, isLoggedIn: isLoggedIn)
    div(.id("fittings-page"), .data("tools", value: isLoggedIn ? "enabled" : "disabled")) {
      a(.class("skip"), .href("#workspace")) { "Skip to fittings" }
      // Static markup only. User-supplied query values are never interpolated into raw HTML.
      HTMLRaw(Self.referenceShell)
      footer(.class("reference-footer")) {
        span { "Reference values · calculation rules remain under review." }
        a(.href("/files/ManD.Groups.pdf"), .target(.blank), .rel(.init(rawValue: "noopener"))) { "Original PDF ↗" }
      }
      HTMLRaw("""
          <dialog id="copy-dialog" aria-labelledby="copy-title">
            <h2 id="copy-title">Copy reference data</h2>
            <p>Automatic copying is unavailable. Select and copy the text below.</p>
            <textarea aria-label="Text to copy" readonly></textarea>
            <button data-action="close-copy">Done</button>
          </dialog>
          """)
      div(.class("reference-toast"), .id("toast"), .role("status")) {}
      noscript {
        "This reference needs JavaScript. "
        a(.href("/files/ManD.Groups.pdf")) { "Open the original PDF." }
      }
    }
  }

  private static let referenceShell = """
    <section class="intro">
      <div><h1>Fitting reference</h1><p>Drawings, reference values, and conditions for your duct path.</p></div>
      <div class="catalog-stat"><strong>230 <span>+ 1</span></strong><span>approved drawings + concept</span></div>
    </section>
    <form class="toolbar" role="search" id="filters">
      <div class="system-toggle" role="group" aria-label="Filter fitting groups by air path">
        <button type="button" data-system="all" aria-pressed="true">All</button>
        <button type="button" data-system="supply" aria-pressed="false">Supply</button>
        <button type="button" data-system="return" aria-pressed="false">Return</button>
      </div>
      <label class="search"><span aria-hidden="true">⌕</span><input id="search" type="search" placeholder="Search all groups by ID, name, or shape…" aria-label="Search fitting groups" autocomplete="off"><kbd>/</kbd></label>
      <label class="select-label">Group<select id="group-filter" aria-label="Filter by group"></select></label>
      <label class="select-label">Values<select id="value-filter"><option value="all">All reference types</option><option value="fixed">Fixed reference</option><option value="conditional">Requires conditions</option></select></label>
      <button class="text-button" type="button" data-action="reset">Reset</button>
      <span id="result-count" class="result-count" aria-live="polite"></span>
    </form>
    <div id="workspace" tabindex="-1"></div>
    """
}
