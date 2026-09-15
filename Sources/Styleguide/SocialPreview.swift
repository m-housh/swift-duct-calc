import Elementary

/// Shared link-preview metadata for the landing page and application pages.
public struct SocialPreview: HTML, Sendable {
  private let title: String
  private let description: String
  private let url: String?
  private let imageURL = "https://ductcalc.pro/images/brand/social-preview.png"
  private let imageAlt = "DuctCalc logo. Residential duct design. ductcalc.pro"

  public init(title: String, description: String, url: String? = nil) {
    self.title = title
    self.description = description
    self.url = url
  }

  public var body: some HTML {
    meta(.custom(name: "property", value: "og:site_name"), .content("DuctCalc"))
    meta(.custom(name: "property", value: "og:title"), .content(title))
    meta(.custom(name: "property", value: "og:description"), .content(description))
    meta(.custom(name: "property", value: "og:type"), .content("website"))
    if let url {
      meta(.custom(name: "property", value: "og:url"), .content(url))
    }
    meta(.custom(name: "property", value: "og:image"), .content(imageURL))
    meta(.custom(name: "property", value: "og:image:type"), .content("image/png"))
    meta(.custom(name: "property", value: "og:image:width"), .content("1200"))
    meta(.custom(name: "property", value: "og:image:height"), .content("630"))
    meta(.custom(name: "property", value: "og:image:alt"), .content(imageAlt))
    meta(.name("twitter:card"), .content("summary_large_image"))
    meta(.name("twitter:title"), .content(title))
    meta(.name("twitter:description"), .content(description))
    meta(.name("twitter:image"), .content(imageURL))
    meta(.name("twitter:image:alt"), .content(imageAlt))
  }
}
