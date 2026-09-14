import CSVParser
import DatabaseClient
import Dependencies
import Elementary
import FittingClient
import Foundation
import ManualDClient
import ManualDCore
import PdfClient
import PdfImportClient
import ProjectClient
import Styleguide

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient
    @Dependency(\.pdfClient) var pdfClient

    switch route {
    case .fittings(let picker):
      return try await picker.renderView(on: self)
    case .home:
      return HomePage(isLoggedIn: isLoggedIn)
    case .homePreview(let step):
      return HomePreviewPage(step: step)
    case .fittingReference(let query):
      @Dependency(\.fittingClient) var fittingClient
      return try await loadView {
        let page = try FittingReferencePage(
          catalog: fittingClient.reference(), query: query, isLoggedIn: isLoggedIn)
        return MainPage(
          theme: await theme ?? .default,
          title: "Fitting reference · Duct Calc",
          stylesheets: ["/fittings/styles.css"],
          scripts: ["app.js"]
            .map { "/fittings/\($0)" }
        ) {
          FittingsView(page: page)
        }
      }
    case .privacyPolicy:
      return await view {
        PrivacyPolicyView()
      }
    case .test:
      // let projectID = UUID(uuidString: "E796C96C-F527-4753-A00A-EBCF25630663")!
      // return await view {
      //   await ResultView {
      //
      //     // return (
      //     //   try await database.projects.getCompletedSteps(projectID),
      //     //   try await projectClient.calculateDuctSizes(projectID)
      //     // )
      //     return try await pdfClient.html(.mock())
      //   } onSuccess: {
      //     $0
      //     // TestPage()
      //     // TestPage(trunks: result.trunks, rooms: result.rooms)
      //   }
      // }
      // return try! await pdfClient.html(.mock())
      return await view {
        TestPage()
      }
    case .login(let route):
      switch route {
      case .index(let next):
        return await view {
          if isLoggedIn {
            LoggedIn(next: next)
          } else {
            LoginForm(next: next)
          }
        }
      case .submit(let login):
        // let _ = try await authenticate(login)
        return try await view {
          try await loadView {
            try await authenticate(login)
          } onSuccess: { _ in
            LoggedIn(next: login.next)
          }
        }
      }
    case .signup(let route):
      switch route {
      case .index:
        return await view {
          LoginForm(style: .signup)
        }
      case .submit(let request):
        // Create a new user and log them in.
        return try await view {
          try await loadView {
            try await createAndAuthenticate(request)
          } onSuccess: { user in
            UserProfileForm(userID: user.id, profile: nil, dismiss: false, signup: true)
          }
        }
      case .submitProfile(let profile):
        return try await afterMutation({
          _ = try await database.userProfiles.create(profile)
        }) {
          try await view {
            try await loadView {
              try await database.projects.fetch(profile.userID, .first)
            } onSuccess: { projects in
              ProjectsTable(userID: profile.userID, projects: projects)
            }
          }
        }
      }
    case .project(let route):
      return try await route.renderView(on: self)

    case .ductulator(let route):
      return try await route.renderView(on: self)

    case .user(let route):
      return try await route.renderView(on: self)
    }
  }

  func view<C: HTML>(
    projectID: Project.ID? = nil,
    @HTMLBuilder inner: () async throws -> C
  ) async rethrows -> AnySendableHTML where C: Sendable {
    let inner = try await inner()
    let theme = await self.theme
    let routeProjectID: Project.ID?
    switch route {
    case .project(.detail(let id, _)), .project(.update(let id, _)): routeProjectID = id
    default: routeProjectID = nil
    }
    var navigation: ProjectNavigation?
    if let id = projectID ?? routeProjectID {
      @Dependency(\.database) var database
      if let user = try? currentUser(),
        let project = try? await database.projects.getForUser(id, user.id)
      {
        @Dependency(\.date.now) var now
        try? await database.projects.recordOpen(id, user.id, now)
        navigation = .init(
          project: project, recent: (try? await database.projects.recent(user.id)) ?? [project])
      }
    }

    return MainPage(displayFooter: displayFooter, theme: theme ?? .default, title: route.pageTitle)
    {
      inner.environment(ProjectViewValue.$navigation, navigation)
    }
  }

  var theme: Theme? {
    get async {
      @Dependency(\.database) var database
      guard let user = try? currentUser() else { return nil }
      return try? await database.userProfiles.fetch(user.id)?.theme
    }
  }

  var displayFooter: Bool {
    switch route {
    case .login, .signup:
      return false
    default:
      return true
    }
  }
}

private enum ProjectPDFImportResult: HTML, Sendable {
  case created(ProjectClient.CreateProjectResponse, ProjectNavigation)
  /// `takenName` is set when a confirmed import's chosen name is already used.
  case confirmation([Project], suggestedName: String, takenName: String?)
  case missingZIP

  var body: some HTML {
    switch self {
    case .created(let response, let navigation):
      ProjectView(
        projectID: response.projectID, activeTab: .rooms,
        completedSteps: response.completedSteps
      ) {
        RoomsView(rooms: response.rooms, sensibleHeatRatio: response.sensibleHeatRatio)
      }.environment(ProjectViewValue.$navigation, navigation)
    case .missingZIP:
      p(.custom(name: "data-project-import-missing-zip", value: "")) {
        "This report does not include a ZIP code. Enter it below to create the project."
      }
    case .confirmation(let projects, let suggestedName, let takenName):
      div(
        .custom(name: "data-project-import-conflict", value: ""),
        .data("suggested-name", value: suggestedName)
      ) {
        p(.class("font-bold mb-2")) {
          takenName == nil ? "Possible duplicate project" : "Project name already used"
        }
        p(.class("mb-2")) {
          if let takenName {
            "A project named “\(takenName)” already exists:"
          } else {
            "The report's name or address matches an existing project:"
          }
        }
        ul(.class("mb-4 list-disc ps-5")) {
          for project in projects {
            li {
              "\(project.name) — \(project.streetAddress), \(project.city), \(project.state) \(project.zipCode)"
            }
          }
        }
        p {
          if takenName == nil {
            "You can create another project for a different duct system at this location. Existing projects will be kept. Keep the suggested name or enter a new one."
          } else {
            "Enter a different name for the new project."
          }
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute {

  func renderView(on request: ViewController.Request) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient

    switch self {
    case .index:
      return try await request.view {
        try await loadView {
          let user = try request.currentUser()
          return try await (
            user.id,
            database.projects.fetch(user.id, .first)
          )

        } onSuccess: { (userID, projects) in
          ProjectsTable(userID: userID, projects: projects)
        }
      }
    case .search(let search):
      return try await request.view {
        try await loadView {
          let user = try request.currentUser()
          return try await (
            user.id,
            database.projects.search(
              user.id, search.query, .init(page: max(1, search.page), per: 25))
          )
        } onSuccess: { (userID, projects) in
          ProjectsTable(userID: userID, projects: projects, query: search.query)
        }
      }
    case .page(let page):
      return try await loadView {
        let user = try request.currentUser()
        return try await (
          user.id,
          database.projects.fetch(user.id, page)
        )
      } onSuccess: { (_, projects) in
        ProjectsTable.Rows(projects: projects)
      }

    case .importPDF(let pdf):
      return try await request.view {
        try await loadView {
          let user = try request.currentUser()
          @Dependency(\.pdfImport) var pdfImport
          var report = try await pdfImport.parseProject(.init(file: pdf.file))
          let parsed = report.project
          var zipCode = parsed.zipCode
          if zipCode.isEmpty {
            guard let zip = pdf.zipCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              zip.range(of: #"^\d{5}(?:-\d{4})?$"#, options: .regularExpression) != nil
            else { return ProjectPDFImportResult.missingZIP }
            zipCode = zip
          }
          let name = pdf.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          report = .init(
            project: .init(
              name: name.isEmpty ? parsed.name : name, streetAddress: parsed.streetAddress,
              city: parsed.city, state: parsed.state, zipCode: zipCode,
              sensibleHeatRatio: parsed.sensibleHeatRatio), rooms: report.rooms)
          do {
            let project = try await database.projects.importPDF(
              user.id, report, pdf.confirmDuplicate)
            return try await afterMutation({}) {
              @Dependency(\.date.now) var now
              try await database.projects.recordOpen(project.id, user.id, now)
              let navigation = try await ProjectNavigation(
                project: project, recent: database.projects.recent(user.id))
              return try await ProjectPDFImportResult.created(
                .init(
                  projectID: project.id, rooms: database.rooms.fetch(project.id),
                  sensibleHeatRatio: project.sensibleHeatRatio,
                  completedSteps: database.projects.getCompletedSteps(project.id)), navigation)
            }
          } catch let conflict as Project.ImportConflict {
            return ProjectPDFImportResult.confirmation(
              conflict.projects, suggestedName: conflict.suggestedName,
              takenName: pdf.confirmDuplicate ? report.project.name : nil)
          }
        }
      }

    case .create(let form):
      let user = try request.currentUser()
      let project = try await database.projects.create(user.id, form)
      return try await afterMutation({}) {
        try await RoomRoute.index.roomsView(on: request, projectID: project.id)
      }

    case .delete(let id):
      try await database.projects.delete(id)
      return try await afterMutation({}) {
        try await SiteRoute.View.ProjectRoute.index.renderView(on: request)
      }

    case .update(let id, let form):
      return try await projectView(on: request, projectID: id) {
        _ = try await database.projects.update(id, form)
      }

    case .detail(let projectID, let route):
      switch route {
      case .index:
        return try await projectView(on: request, projectID: projectID)
      case .componentLoss(let route):
        return try await route.renderView(on: request, projectID: projectID)
      case .ductSizing(let route):
        return try await route.renderView(on: request, projectID: projectID)
      case .equipment(let route):
        return try await route.renderView(on: request, projectID: projectID)
      case .equivalentLength(let route):
        return try await route.renderView(on: request, projectID: projectID)
      case .frictionRate(let route):
        return try await route.renderView(on: request, projectID: projectID)
      case .pdf:
        // FIX: This should return a pdf to download or be wrapped in a
        //      result view.
        // return try! await projectClient.toHTML(projectID)
        // This get's handled elsewhere because it returns a response, not a view.
        fatalError()
      case .rooms(let route):
        return try await route.renderView(on: request, projectID: projectID)
      }
    }

  }

  func projectView(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          guard let detail = try await database.projects.detail(projectID) else {
            throw NotFoundError()
          }
          @Dependency(\.manualD) var manualD
          let lengths = try await database.equivalentLengths.fetchMax(projectID)
          let friction = try? await manualD.frictionRate(
            equipmentInfo: detail.equipmentInfo,
            componentLosses: detail.componentLosses, effectiveLength: lengths)
          return (try await database.projects.getCompletedSteps(projectID), detail, friction)
        } onSuccess: { (steps, detail, friction) in
          ProjectView(projectID: projectID, activeTab: .project, completedSteps: steps) {
            ProjectDetail(project: detail.project, detail: detail, frictionRate: friction)
          }
        }
      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.EquipmentInfoRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return try await equipmentView(on: request, projectID: projectID)

    case .submit(let form):
      return try await equipmentView(on: request, projectID: projectID) {
        _ = try await database.equipment.create(form)
      }

    case .update(let id, let updates):
      return try await equipmentView(on: request, projectID: projectID) {
        _ = try await database.equipment.update(id, updates)
      }
    }
  }

  func equipmentView(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          return (
            try await database.projects.getCompletedSteps(projectID),
            try await database.equipment.fetch(projectID)
          )
        } onSuccess: { (steps, equipment) in
          ProjectView(projectID: projectID, activeTab: .equipment, completedSteps: steps) {
            EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
          }
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.RoomRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.csvParser) var csvParser
    @Dependency(\.database) var database

    switch self {

    case .pdf(let pdf):
      return try await roomsView(on: request, projectID: projectID) {
        let user = try request.currentUser()
        @Dependency(\.pdfImport) var pdfImport
        let loads = try await pdfImport.parseRooms(pdf)
        _ = try await database.rooms.importLoads(projectID, user.id, loads)
      }

    case .csv(let csv):
      return try await roomsView(on: request, projectID: projectID) {
        let user = try request.currentUser()
        let rooms = try await csvParser.parseRooms(csv)
        _ = try await database.rooms.createFromCSV(projectID, user.id, rooms)
      }
    // return EmptyHTML()

    case .delete(let id):
      return try await roomsView(on: request, projectID: projectID) {
        try await database.rooms.delete(id)
      }

    case .index:
      return try await roomsView(on: request, projectID: projectID)

    case .submit(let form):
      return try await roomsView(on: request, projectID: projectID) {
        _ = try await database.rooms.create(projectID, form)
      }

    case .update(let id, let form):
      return try await roomsView(on: request, projectID: projectID) {
        _ = try await database.rooms.update(id, form)
      }

    case .updateSensibleHeatRatio(let form):
      return try await roomsView(on: request, projectID: projectID) {
        _ = try await database.projects.update(
          form.projectID,
          .init(sensibleHeatRatio: form.sensibleHeatRatio)
        )
      }
    }
  }

  func roomsView(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          return (
            try await database.projects.getCompletedSteps(projectID),
            try await database.rooms.fetch(projectID),
            try await database.projects.getSensibleHeatRatio(projectID)
          )
        } onSuccess: { (steps, rooms, shr) in
          ProjectView(projectID: projectID, activeTab: .rooms, completedSteps: steps) {
            RoomsView(rooms: rooms, sensibleHeatRatio: shr)
          }
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.FrictionRateRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    switch self {
    case .index:
      return try await view(on: request, projectID: projectID)
    case .applyTemplate(let template):
      return try await view(
        on: request, projectID: projectID, filterStep: template == .shared ? nil : template
      ) {
        try await database.componentLosses.applyTemplate(projectID, template)
      }
    case .filterResults(let allowance):
      let user = try request.currentUser()
      let value = try AirFilter.Selection(model: "", allowance: allowance).validatedAllowance()
      return FilterLookupResults(
        library: try await database.filters.fetch(user.id),
        airflow: try await database.equipment.fetch(projectID)?.largerAirflow,
        allowance: value)
    case .applyFilter(let selection):
      return try await view(on: request, projectID: projectID) {
        try await database.filters.apply(try request.currentUser().id, projectID, selection)
      }
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    filterStep: FrictionRateTemplate? = nil,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          let library = try await database.filters.fetch(try request.currentUser().id)
          let allowance = try await database.filters.allowance(projectID)
          let equipment = try await database.equipment.fetch(projectID)
          let componentLosses = try await database.componentLosses.fetch(projectID)
          let lengths = try await database.equivalentLengths.fetchMax(projectID)

          return (
            try await database.projects.getCompletedSteps(projectID),
            componentLosses,
            lengths,
            equipment, library, allowance,
            try await manualD.frictionRate(
              equipmentInfo: equipment,
              componentLosses: componentLosses,
              effectiveLength: lengths
            )
          )
        } onSuccess: { (steps, losses, lengths, equipment, library, allowance, frictionRate) in
          ProjectView(projectID: projectID, activeTab: .frictionRate, completedSteps: steps) {
            FrictionRateView(
              componentLosses: losses,
              equivalentLengths: lengths,
              frictionRate: frictionRate, blowerStatic: equipment?.staticPressure,
              airflow: equipment?.largerAirflow, filterLibrary: library,
              filterAllowance: allowance, filterStep: filterStep
            )
          }

        }
      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.ComponentLossRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return EmptyHTML()
    case .delete(let id):
      return try await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.delete(id)
      }
    case .submit(let form):
      return try await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.create(form)
      }

    case .update(let id, let form):
      return try await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.update(id, form)
      }
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          return (
            try await database.projects.getCompletedSteps(projectID),
            try await projectClient.frictionRate(projectID),
            try await database.equipment.fetch(projectID),
            try await database.filters.fetch(try request.currentUser().id),
            try await database.filters.allowance(projectID)
          )
        } onSuccess: { (steps, response, equipment, library, allowance) in
          ProjectView(projectID: projectID, activeTab: .frictionRate, completedSteps: steps) {
            FrictionRateView(
              componentLosses: response.componentLosses,
              equivalentLengths: response.equivalentLengths,
              frictionRate: response.frictionRate, blowerStatic: equipment?.staticPressure,
              airflow: equipment?.largerAirflow, filterLibrary: library, filterAllowance: allowance
            )
          }

        }
      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    do {
      let user = try request.currentUser()
      guard try await database.projects.getForUser(projectID, user.id) != nil else {
        throw NotFoundError()
      }
      let pathID: EquivalentLength.ID?
      switch self {
      case .delete(let id), .duplicate(let id): pathID = id
      default: pathID = nil
      }
      if let pathID {
        guard let path = try await database.equivalentLengths.get(pathID),
          path.projectID == projectID
        else { throw NotFoundError() }
      }
    }

    switch self {
    case .editor, .savePath, .favorite:
      return try await renderPathEditor(on: request, projectID: projectID)

    case .duplicate(let id):
      return try await Self.editor(id).renderPathEditor(
        on: request, projectID: projectID, duplicating: true)

    case .guided(let route):
      return try await route.renderView(on: request, projectID: projectID)

    case .delete(let id):
      return try await view(on: request, projectID: projectID) {
        try await database.equivalentLengths.delete(id)
      }

    case .index:
      return try await self.view(on: request, projectID: projectID)

    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          return (
            try await database.projects.getCompletedSteps(projectID),
            try await database.equivalentLengths.fetch(projectID),
            try await database.equipment.fetch(projectID)?.coolingCFM
          )
        } onSuccess: { (steps, equivalentLengths, coolingCFM) in
          ProjectView(projectID: projectID, activeTab: .equivalentLength, completedSteps: steps) {
            EffectiveLengthsView(effectiveLengths: equivalentLengths, coolingCFM: coolingCFM)
              .environment(ProjectViewValue.$projectID, projectID)
          }
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.DuctSizingRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD
    @Dependency(\.projectClient) var projectClient

    switch self {
    case .index:
      return try await view(on: request, projectID: projectID)

    case .deleteRectangularSize(let roomID, let request):
      let room = try await database.rooms.clearRectangularSize(roomID, request.register)
      return try await afterMutation({}) {
        try await loadView {
          let rooms = try await projectClient.calculateRoomDuctSizes(projectID)
          guard
            let result =
              rooms
              .first(where: { $0.roomID == room.id && $0.roomRegister == request.register })
          else {
            throw ValidationError("This register is no longer available. Reload the duct sizes.")
          }
          return (room: result, rooms: rooms)
        } onSuccess: { result in
          DuctSizingView.RoomUpdate(room: result.room, rooms: result.rooms)
            .environment(ProjectViewValue.$projectID, projectID)
        }
      }

    case .roomRectangularForm(let roomID, let form):
      let room = try await database.rooms.updateRectangularSize(
        roomID,
        .init(id: form.id ?? .init(), register: form.register, height: form.height)
      )
      return try await afterMutation({}) {
        try await loadView {
          let rooms = try await projectClient.calculateRoomDuctSizes(projectID)
          guard
            let result =
              rooms
              .first(where: { $0.roomID == room.id && $0.roomRegister == form.register })
          else {
            throw ValidationError("This register is no longer available. Reload the duct sizes.")
          }
          return (room: result, rooms: rooms)
        } onSuccess: { result in
          DuctSizingView.RoomUpdate(room: result.room, rooms: result.rooms)
            .environment(ProjectViewValue.$projectID, projectID)
        }
      }

    case .rectangularSizes(let form):
      return try await view(on: request, projectID: projectID) {
        try await database.rooms.setRectangularSizes(
          Dictionary(grouping: form.rooms, by: \.roomID).mapValues { $0.map(\.register) },
          form.height)
      }

    case .clearRectangularSizes(let rooms):
      return try await view(on: request, projectID: projectID) {
        try await database.rooms.setRectangularSizes(
          Dictionary(grouping: rooms, by: \.roomID).mapValues { $0.map(\.register) }, nil)
      }

    case .trunk(let route):
      switch route {
      case .delete(let id):
        return try await view(on: request, projectID: projectID) {
          try await database.trunkSizes.delete(id)
        }
      case .submit(let form):
        return try await view(on: request, projectID: projectID) {
          _ = try await database.trunkSizes.create(
            form.toCreate(logger: request.logger)
          )
        }

      case .update(let id, let form):
        return try await view(on: request, projectID: projectID) {
          _ = try await database.trunkSizes.update(id, form.toUpdate())
        }
      }
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.projectClient) var project

    return try await afterMutation(catching) {
      return try await request.view(projectID: projectID) {
        try await loadView {
          let steps = try await database.projects.getCompletedSteps(projectID)
          let content: Result<DuctSizes, Project.DuctSizingUnavailable>
          do {
            content = .success(try await project.calculateDuctSizes(projectID))
          } catch let error as Project.DuctSizingUnavailable {
            content = .failure(error)
          }
          return ProjectView(projectID: projectID, activeTab: .ductSizing, completedSteps: steps) {
            switch content {
            case .success(let sizes): DuctSizingView(ductSizes: sizes)
            case .failure(let error): DuctSizingErrorView(error: error)
            }
          }
        }
      }
    }
  }
}

extension SiteRoute.View.UserRoute {

  func renderView(on request: ViewController.Request) async throws -> AnySendableHTML {
    @Dependency(\.auth) var auth

    switch self {
    case .logout:
      return try await request.view {
        try await loadView {
          try auth.logout()
        } onSuccess: {
          LoginForm(next: nil)
        }
      }
    case .profile(let route):
      return try await route.renderView(on: request)
    case .templates(let route):
      return try await route.renderView(on: request)
    case .filters(let route):
      return try await route.renderView(on: request)
    }
  }
}

extension SiteRoute.View.UserRoute.Profile {

  func renderView(
    on request: ViewController.Request
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return try await view(on: request)
    case .submit(let form):
      return try await view(on: request) {
        _ = try await database.userProfiles.create(form)
      }
    case .update(let id, let updates):
      return try await view(on: request) {
        _ = try await database.userProfiles.update(id, updates)
      }
    }
  }

  func view(
    on request: ViewController.Request,
    catching: (@Sendable () async throws -> Void)? = nil
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    return try await afterMutation(catching) {
      return try await request.view {
        try await loadView {
          let user = try request.currentUser()
          return (
            user,
            try await database.userProfiles.fetch(user.id)
          )
        } onSuccess: { (user, profile) in
          UserView(user: user, profile: profile)
        }
      }
    }
  }
}

extension SiteRoute.View.DuctulatorRoute {

  func renderView(
    on request: ViewController.Request
  ) async throws -> AnySendableHTML {
    @Dependency(\.manualD) var manualD

    switch self {
    case .index:
      return await request.view {
        DuctulatorView(
          isLoggedIn: request.isLoggedIn
        )
      }
    case .submit(let form):
      return try await loadView {
        let ductSize = try await manualD.ductSize(cfm: form.cfm, frictionRate: form.frictionRate)
        var rectangularSize: ManualDClient.RectangularSize? = nil
        if let height = form.height {
          rectangularSize = try await manualD.rectangularSize(
            round: ductSize.finalSize, height: height)
        }
        return (ductSize, rectangularSize)
      } onSuccess: { (ductSize, rectangularSize) in
        DuctulatorView.Result(ductSize: ductSize, rectangularSize: rectangularSize)
      }
    }
  }
}
