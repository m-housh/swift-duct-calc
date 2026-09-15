import ManualDCore

extension SiteRoute.View {
  var pageTitle: String {
    let title: String
    switch self {
    case .home: title = "Home"
    case .homePreview(let step): title = step.title
    case .privacyPolicy: title = "Privacy policy"
    case .login: title = "Login"
    case .signup: title = "Sign up"
    case .user(.keybindings): title = "Keybindings"
    case .user(.profile): title = "Profile"
    case .user(.templates): title = "Path templates"
    case .user(.filters(.index(let query))):
      title = query.tab == "preferences" ? "Design preferences" : "Filter library"
    case .user: title = "Account"
    case .ductulator: title = "Ductulator"
    case .fittings: title = "Fitting picker"
    case .fittingReference: title = "Fitting reference"
    case .test: title = "Preview"
    case .project(.detail(_, let detail)):
      switch detail {
      case .index: title = "Project"
      case .rooms: title = "Room loads"
      case .equipment: title = "Equipment"
      case .equivalentLength: title = "Equivalent lengths"
      case .frictionRate, .componentLoss: title = "Friction rate"
      case .ductSizing: title = "Duct sizes"
      case .pdf: title = "Project PDF"
      }
    case .project: title = "Projects"
    }
    return "\(title) · Duct Calc"
  }
}
