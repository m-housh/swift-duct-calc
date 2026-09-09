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

  func render() async -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient
    @Dependency(\.pdfClient) var pdfClient

    switch route {
    case .fittings(let picker):
      return await picker.renderView(on: self)
    case .home:
      return await view {
        HomeView()
      }
    case .fittingReference(let query):
      @Dependency(\.fittingClient) var fittingClient
      return await ResultView {
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
        return await view {
          await ResultView {
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
        return await view {
          await ResultView {
            try await createAndAuthenticate(request)
          } onSuccess: { user in
            MainPage {
              UserProfileForm(userID: user.id, profile: nil, dismiss: false, signup: true)
            }
          }
        }
      case .submitProfile(let profile):
        return await view {
          await ResultView {
            _ = try await database.userProfiles.create(profile)
            let userID = profile.userID
            // let user = try currentUser()
            return (
              userID,
              try await database.projects.fetch(userID, .init(page: 1, per: 25)),
              profile.theme
            )
          } onSuccess: { (userID, projects, theme) in
            MainPage(displayFooter: true, theme: theme) {
              ProjectsTable(userID: userID, projects: projects)
            }
          }
        }
      }
    case .project(let route):
      return await route.renderView(on: self)

    case .ductulator(let route):
      return await route.renderView(on: self)

    case .user(let route):
      return await route.renderView(on: self)
    }
  }

  func view<C: HTML>(
    @HTMLBuilder inner: () async -> C
  ) async -> AnySendableHTML where C: Sendable {
    let inner = await inner()
    let theme = await self.theme

    return MainPage(displayFooter: displayFooter, theme: theme ?? .default) {
      inner
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
  case created(ProjectClient.CreateProjectResponse)
  case confirmation([Project])
  case missingZIP

  var body: some HTML {
    switch self {
    case .created(let response):
      ProjectView(
        projectID: response.projectID, activeTab: .rooms,
        completedSteps: response.completedSteps
      ) {
        RoomsView(rooms: response.rooms, sensibleHeatRatio: response.sensibleHeatRatio)
      }
    case .missingZIP:
      p(.custom(name: "data-project-import-missing-zip", value: "")) {
        "This report does not include a ZIP code. Enter it below to create the project."
      }
    case .confirmation(let projects):
      div(.custom(name: "data-project-import-conflict", value: "")) {
        p(.class("font-bold mb-2")) { "Possible duplicate project" }
        p(.class("mb-2")) { "The report's name or address matches an existing project:" }
        ul(.class("mb-4")) {
          for project in projects {
            li {
              "\(project.name) — \(project.streetAddress), \(project.city), \(project.state) \(project.zipCode)"
            }
          }
        }
        p {
          "You can create another project for a different duct system at this location. Existing projects will be kept. A matching name will receive a numbered suffix."
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute {

  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient

    switch self {
    case .index:
      return await request.view {
        await ResultView {
          let user = try request.currentUser()
          return try await (
            user.id,
            database.projects.fetch(user.id, .first)
          )

        } onSuccess: { (userID, projects) in
          ProjectsTable(userID: userID, projects: projects)
        }
      }
    case .page(let page):
      return await ResultView {
        let user = try request.currentUser()
        return try await (
          user.id,
          database.projects.fetch(user.id, page)
        )
      } onSuccess: { (userID, projects) in
        ProjectsTable(userID: userID, projects: projects)
      }

    case .importPDF(let pdf):
      return await request.view {
        await ResultView {
          let user = try request.currentUser()
          @Dependency(\.pdfImport) var pdfImport
          var report = try await pdfImport.parseProject(.init(file: pdf.file))
          if report.project.zipCode.isEmpty {
            guard let zip = pdf.zipCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              zip.range(of: #"^\d{5}(?:-\d{4})?$"#, options: .regularExpression) != nil
            else { return ProjectPDFImportResult.missingZIP }
            let parsed = report.project
            report = .init(
              project: .init(
                name: parsed.name, streetAddress: parsed.streetAddress,
                city: parsed.city, state: parsed.state, zipCode: zip,
                sensibleHeatRatio: parsed.sensibleHeatRatio), rooms: report.rooms)
          }
          do {
            let project = try await database.projects.importPDF(
              user.id, report, pdf.confirmDuplicate)
            return try await ProjectPDFImportResult.created(
              .init(
                projectID: project.id, rooms: database.rooms.fetch(project.id),
                sensibleHeatRatio: project.sensibleHeatRatio,
                completedSteps: database.projects.getCompletedSteps(project.id)))
          } catch let conflict as Project.ImportConflict {
            return ProjectPDFImportResult.confirmation(conflict.projects)
          }
        }
      }

    case .create(let form):
      return await request.view {
        await ResultView {
          let user = try request.currentUser()
          return try await projectClient.createProject(user.id, form)
        } onSuccess: { response in
          ProjectView(
            projectID: response.projectID,
            activeTab: .rooms,
            completedSteps: response.completedSteps
          ) {
            RoomsView(rooms: response.rooms, sensibleHeatRatio: response.sensibleHeatRatio)
          }
        }
      }

    case .delete(let id):
      return await ResultView {
        try await database.projects.delete(id)
      }

    case .update(let id, let form):
      return await projectView(on: request, projectID: id) {
        _ = try await database.projects.update(id, form)
      }

    case .detail(let projectID, let route):
      switch route {
      case .index:
        return await projectView(on: request, projectID: projectID)
      case .componentLoss(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .ductSizing(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .equipment(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .equivalentLength(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .frictionRate(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .pdf:
        // FIX: This should return a pdf to download or be wrapped in a
        //      result view.
        // return try! await projectClient.toHTML(projectID)
        // This get's handled elsewhere because it returns a response, not a view.
        fatalError()
      case .rooms(let route):
        return await route.renderView(on: request, projectID: projectID)
      }
    }

  }

  func projectView(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    return await request.view {
      await ResultView {
        try await catching()
        guard let project = try await database.projects.get(projectID) else {
          throw NotFoundError()
        }
        return (
          try await database.projects.getCompletedSteps(project.id),
          project
        )
      } onSuccess: { (steps, project) in
        ProjectView(projectID: projectID, activeTab: .project, completedSteps: steps) {
          ProjectDetail(project: project)
        }
      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.EquipmentInfoRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return await equipmentView(on: request, projectID: projectID)

    case .submit(let form):
      return await equipmentView(on: request, projectID: projectID) {
        _ = try await database.equipment.create(form)
      }

    case .update(let id, let updates):
      return await equipmentView(on: request, projectID: projectID) {
        _ = try await database.equipment.update(id, updates)
      }
    }
  }

  func equipmentView(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    return await request.view {
      await ResultView {
        try await catching()
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

extension SiteRoute.View.ProjectRoute.RoomRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.csvParser) var csvParser
    @Dependency(\.database) var database

    switch self {

    case .pdf(let pdf):
      return await roomsView(on: request, projectID: projectID) {
        let user = try request.currentUser()
        @Dependency(\.pdfImport) var pdfImport
        let loads = try await pdfImport.parseRooms(pdf)
        _ = try await database.rooms.importLoads(projectID, user.id, loads)
      }

    case .csv(let csv):
      return await roomsView(on: request, projectID: projectID) {
        let user = try request.currentUser()
        let rooms = try await csvParser.parseRooms(csv)
        _ = try await database.rooms.createFromCSV(projectID, user.id, rooms)
      }
    // return EmptyHTML()

    case .delete(let id):
      return await ResultView {
        try await database.rooms.delete(id)
      }

    case .index:
      return await roomsView(on: request, projectID: projectID)

    case .submit(let form):
      return await roomsView(on: request, projectID: projectID) {
        _ = try await database.rooms.create(projectID, form)
      }

    case .update(let id, let form):
      return await roomsView(on: request, projectID: projectID) {
        _ = try await database.rooms.update(id, form)
      }

    case .updateSensibleHeatRatio(let form):
      return await roomsView(on: request, projectID: projectID) {
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
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    return await request.view {
      await ResultView {
        try await catching()
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

extension SiteRoute.View.ProjectRoute.FrictionRateRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    switch self {
    case .index:
      return await view(on: request, projectID: projectID)
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    return await request.view {
      await ResultView {
        let equipment = try await database.equipment.fetch(projectID)
        let componentLosses = try await database.componentLosses.fetch(projectID)
        let lengths = try await database.equivalentLengths.fetchMax(projectID)

        return (
          try await database.projects.getCompletedSteps(projectID),
          componentLosses,
          lengths,
          try await manualD.frictionRate(
            equipmentInfo: equipment,
            componentLosses: componentLosses,
            effectiveLength: lengths
          )
        )
      } onSuccess: { (steps, losses, lengths, frictionRate) in
        ProjectView(projectID: projectID, activeTab: .frictionRate, completedSteps: steps) {
          FrictionRateView(
            componentLosses: losses,
            equivalentLengths: lengths,
            frictionRate: frictionRate
          )
        }

      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.ComponentLossRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return EmptyHTML()
    case .delete(let id):
      return await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.delete(id)
      }
    case .submit(let form):
      return await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.create(form)
      }

    case .update(let id, let form):
      return await view(on: request, projectID: projectID) {
        _ = try await database.componentLosses.update(id, form)
      }
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {

    @Dependency(\.database) var database
    @Dependency(\.projectClient) var projectClient

    return await request.view {
      await ResultView {
        try await catching()
        return (
          try await database.projects.getCompletedSteps(projectID),
          try await projectClient.frictionRate(projectID)
        )
      } onSuccess: { (steps, response) in
        ProjectView(projectID: projectID, activeTab: .frictionRate, completedSteps: steps) {
          FrictionRateView(
            componentLosses: response.componentLosses,
            equivalentLengths: response.equivalentLengths,
            frictionRate: response.frictionRate
          )
        }

      }
    }
  }

}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    do {
      let user = try request.currentUser()
      guard try await database.projects.getForUser(projectID, user.id) != nil else {
        throw NotFoundError()
      }
      let pathID: EquivalentLength.ID?
      switch self {
      case .delete(let id), .update(let id, _): pathID = id
      case .submit(.one(let form)): pathID = form.id
      case .submit(.two(let form)): pathID = form.id
      default: pathID = nil
      }
      if let pathID {
        guard let path = try await database.equivalentLengths.get(pathID),
          path.projectID == projectID
        else { throw NotFoundError() }
      }
    } catch {
      return p(.class("alert alert-error"), .role("alert")) {
        "This project or path is unavailable."
      }
    }

    switch self {
    case .editor, .savePath, .favorite:
      return await renderPathEditor(on: request, projectID: projectID)

    case .guided(let route):
      return await route.renderView(on: request, projectID: projectID)

    case .delete(let id):
      return await ResultView {
        try await database.equivalentLengths.delete(id)
      }

    case .index:
      return await self.view(on: request, projectID: projectID)

    case .field(let type, let style):
      switch type {
      case .straightLength:
        return StraightLengthField()
      case .group:
        // FIX:
        return GroupField(style: style ?? .supply)
      }

    case .update(let id, let form):
      return await view(on: request, projectID: projectID) {
        if try await database.equivalentLengths.get(id)?.templateSnapshot != nil {
          throw ValidationError("Open this path in the guided editor to keep its fitting details.")
        }
        _ = try await database.equivalentLengths.update(id, .init(form: form, projectID: projectID))
      }

    case .submit(let step):
      switch step {
      case .one(let stepOne):
        return await ResultView {
          var effectiveLength: EquivalentLength? = nil
          if let id = stepOne.id {
            effectiveLength = try await database.equivalentLengths.get(id)
          }
          return effectiveLength
        } onSuccess: { effectiveLength in
          EffectiveLengthForm.StepTwo(
            projectID: projectID,
            stepOne: stepOne,
            effectiveLength: effectiveLength
          )
        }
      case .two(let stepTwo):
        return await ResultView {
          request.logger.debug("ViewController: Got step two...")
          var effectiveLength: EquivalentLength? = nil
          if let id = stepTwo.id {
            effectiveLength = try await database.equivalentLengths.get(id)
          }
          return effectiveLength
        } onSuccess: { effectiveLength in
          return EffectiveLengthForm.StepThree(
            projectID: projectID, effectiveLength: effectiveLength, stepTwo: stepTwo
          )
        }
      case .three(let stepThree):
        return await view(on: request, projectID: projectID) {
          _ = try await database.equivalentLengths.create(
            .init(form: stepThree, projectID: projectID)
          )
        }

      }
    }

  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database
    return await request.view {
      await ResultView {
        try await catching()
        return (
          try await database.projects.getCompletedSteps(projectID),
          try await database.equivalentLengths.fetch(projectID)
        )
      } onSuccess: { (steps, equivalentLengths) in
        ProjectView(projectID: projectID, activeTab: .equivalentLength, completedSteps: steps) {
          EffectiveLengthsView(effectiveLengths: equivalentLengths)
            .environment(ProjectViewValue.$projectID, projectID)
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.DuctSizingRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD
    @Dependency(\.projectClient) var projectClient

    switch self {
    case .index:
      return await view(on: request, projectID: projectID)

    case .deleteRectangularSize(let roomID, let request):
      return await ResultView {
        let room = try await database.rooms.deleteRectangularSize(roomID, request.rectangularSizeID)
        return try await projectClient.calculateRoomDuctSizes(projectID)
          .filter({ $0.roomID == room.id && $0.roomRegister == request.register })
          .first!
      } onSuccess: { room in
        DuctSizingView.RoomRow(room: room)
      }

    case .roomRectangularForm(let roomID, let form):
      return await ResultView {
        let room = try await database.rooms.updateRectangularSize(
          roomID,
          .init(id: form.id ?? .init(), register: form.register, height: form.height)
        )
        return try await projectClient.calculateRoomDuctSizes(projectID)
          .filter({ $0.roomID == room.id && $0.roomRegister == form.register })
          .first!
      } onSuccess: { room in
        DuctSizingView.RoomRow(room: room)
      }

    case .trunk(let route):
      switch route {
      case .delete(let id):
        return await ResultView {
          try await database.trunkSizes.delete(id)
        }
      case .submit(let form):
        request.logger.debug("Trunk Form: \(form)")
        return await view(on: request, projectID: projectID) {
          _ = try await database.trunkSizes.create(
            form.toCreate(logger: request.logger)
          )
        }

      case .update(let id, let form):
        return await view(on: request, projectID: projectID) {
          _ = try await database.trunkSizes.update(id, form.toUpdate())
        }
      }
    }
  }

  func view(
    on request: ViewController.Request,
    projectID: Project.ID,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database
    @Dependency(\.projectClient) var project

    return await request.view {
      await ResultView {
        try await catching()
        return (
          try await database.projects.getCompletedSteps(projectID),
          try await project.calculateDuctSizes(projectID)
        )
      } onSuccess: { (steps, ducts) in
        ProjectView(projectID: projectID, activeTab: .ductSizing, completedSteps: steps) {
          DuctSizingView(ductSizes: ducts)
        }
      }
    }
  }
}

extension SiteRoute.View.UserRoute {

  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.auth) var auth

    switch self {
    case .logout:
      return await request.view {
        await ResultView {
          try auth.logout()
        } onSuccess: {
          LoginForm(next: nil)
        }
      }
    case .profile(let route):
      return await route.renderView(on: request)
    case .templates(let route):
      return await route.renderView(on: request)
    }
  }
}

extension SiteRoute.View.UserRoute.Profile {

  func renderView(
    on request: ViewController.Request
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return await view(on: request)
    case .submit(let form):
      return await view(on: request) {
        _ = try await database.userProfiles.create(form)
      }
    case .update(let id, let updates):
      return await view(on: request) {
        _ = try await database.userProfiles.update(id, updates)
      }
    }
  }

  func view(
    on request: ViewController.Request,
    catching: @escaping @Sendable () async throws -> Void = {}
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    return await request.view {
      await ResultView {
        try await catching()
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

extension SiteRoute.View.DuctulatorRoute {

  func renderView(
    on request: ViewController.Request
  ) async -> AnySendableHTML {
    @Dependency(\.manualD) var manualD

    switch self {
    case .index:
      return await request.view {
        DuctulatorView(
          isLoggedIn: request.isLoggedIn
        )
      }
    case .submit(let form):
      return await ResultView {
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
