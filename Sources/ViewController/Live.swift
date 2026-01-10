import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore

extension ViewController.Request {

  func render() async throws -> AnySendableHTML {

    @Dependency(\.database) var database

    switch route {
    case .test:
      return view {
        TestPage()
      }
    case .login(let route):
      switch route {
      case .index(let next):
        return view {
          LoginForm(next: next)
        }
      case .submit(let login):
        let _ = try await authenticate(login)
        return view {
          LoggedIn(next: login.next)
        }
      }
    case .signup(let route):
      switch route {
      case .index:
        return view {
          LoginForm(style: .signup)
        }
      case .submit(let request):
        // Create a new user and log them in.
        let user = try await createAndAuthenticate(request)
        let projects = try await database.projects.fetch(user.id, .init(page: 1, per: 25))
        return view {
          ProjectsTable(userID: user.id, projects: projects)
        }
      }
    case .project(let route):
      return try await route.renderView(on: self)
    default:
      // FIX: FIX
      return _render(isHtmxRequest: false) {
        div { "Fix me!" }
      }
    }
  }

  func view<C: HTML>(
    @HTMLBuilder inner: () -> C
  ) -> AnySendableHTML where C: Sendable {
    _render(isHtmxRequest: isHtmxRequest, showSidebar: showSidebar) {
      inner()
    }
  }

  var showSidebar: Bool {
    switch route {
    case .login, .signup, .project(.page):
      return false
    default:
      return true
    }
  }
}

extension SiteRoute.View.ProjectRoute {

  func renderView(on request: ViewController.Request) async throws -> AnySendableHTML {
    @Dependency(\.database) var database
    let user = try request.currentUser()

    switch self {
    case .index:
      let projects = try await database.projects.fetchPage(userID: user.id)
      return request.view {
        ProjectsTable(userID: user.id, projects: projects)
      }
    case .page(let page):
      let projects = try await database.projects.fetch(user.id, page)
      return ProjectsTable(userID: user.id, projects: projects)

    case .form(let id, let dismiss):
      request.logger.debug("Project form: \(id != nil ? "Fetching project for: \(id!)" : "N/A")")
      var project: Project? = nil
      if let id, dismiss == false {
        project = try await database.projects.get(id)
      }
      request.logger.debug(
        project == nil ? "No project found" : "Showing form for existing project"
      )
      return ProjectForm(dismiss: dismiss, project: project)

    case .create(let form):
      let project = try await database.projects.create(user.id, form)
      try await database.componentLoss.createDefaults(projectID: project.id)
      return ProjectView(projectID: project.id, activeTab: .rooms)

    case .delete(let id):
      try await database.projects.delete(id)
      return EmptyHTML()

    case .update(let id, let form):
      let project = try await database.projects.update(id, form)
      return ProjectView(projectID: project.id, activeTab: .project)

    case .detail(let projectID, let route):
      switch route {
      case .index(let tab):
        return request.view {
          ProjectView(projectID: projectID, activeTab: tab)
        }
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
      case .rooms(let route):
        return try await route.renderView(on: request, projectID: projectID)
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
      let equipment = try await database.equipment.fetch(projectID)
      return EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
    case .form(let dismiss):
      let equipment = try await database.equipment.fetch(projectID)
      return EquipmentInfoForm(dismiss: dismiss, projectID: projectID, equipmentInfo: equipment)
    case .submit(let form):
      let equipment = try await database.equipment.create(form)
      return EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
    case .update(let id, let updates):
      let equipment = try await database.equipment.update(id, updates)
      return EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
    }
  }
}

extension SiteRoute.View.ProjectRoute.RoomRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {

    case .delete(let id):
      try await database.rooms.delete(id)
      return EmptyHTML()

    case .form(let id, let dismiss):
      var room: Room? = nil
      if let id, dismiss == false {
        room = try await database.rooms.get(id)
      }
      return RoomForm(dismiss: dismiss, projectID: projectID, room: room)

    case .index:
      return request.view {
        ProjectView(projectID: projectID, activeTab: .rooms)
      }

    case .submit(let form):
      request.logger.debug("New room form submitted.")
      // FIX: Just return a room row??
      let _ = try await database.rooms.create(form)
      return request.view {
        ProjectView(projectID: projectID, activeTab: .rooms)
      }

    case .update(let id, let form):
      let _ = try await database.rooms.update(id, form)
      return ProjectView(projectID: projectID, activeTab: .rooms)

    case .updateSensibleHeatRatio(let form):
      let _ = try await database.projects.update(
        form.projectID,
        .init(sensibleHeatRatio: form.sensibleHeatRatio)
      )
      return request.view {
        ProjectView(projectID: projectID, activeTab: .rooms)
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.FrictionRateRoute {
  func renderView(on request: ViewController.Request, projectID: Project.ID) async throws
    -> AnySendableHTML
  {
    @Dependency(\.database) var database

    switch self {
    case .index:
      // let equipment = try await database.equipment.fetch(projectID)
      // let componentLosses = try await database.componentLoss.fetch(projectID)

      return request.view {
        ProjectView(projectID: projectID, activeTab: .frictionRate)
      }

    case .form(let type, let dismiss):
      // FIX: Forms need to reference existing items.
      switch type {
      case .equipmentInfo:
        return div { "REMOVE ME!" }
      // return EquipmentForm(dismiss: dismiss, projectID: projectID)
      case .componentPressureLoss:
        return ComponentLossForm(dismiss: dismiss, projectID: projectID, componentLoss: nil)
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
      _ = try await database.componentLoss.delete(id)
      return EmptyHTML()
    case .submit(let form):
      _ = try await database.componentLoss.create(form)
      return ProjectView(projectID: projectID, activeTab: .frictionRate)
    case .update(let id, let form):
      _ = try await database.componentLoss.update(id, form)
      return ProjectView(projectID: projectID, activeTab: .frictionRate)
    }
  }
}

extension SiteRoute.View.ProjectRoute.FrictionRateRoute.FormType {
  var id: String {
    switch self {
    case .equipmentInfo:
      return "equipmentForm"
    case .componentPressureLoss:
      return "componentLossForm"
    }
  }
}

extension SiteRoute.View.ProjectRoute.EquivalentLengthRoute {

  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async throws -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {

    case .delete(let id):
      try await database.effectiveLength.delete(id)
      return EmptyHTML()

    case .index:
      return request.view {
        ProjectView(projectID: projectID, activeTab: .equivalentLength)
      }
    case .form(let dismiss):
      return EffectiveLengthForm(projectID: projectID, dismiss: dismiss)

    case .field(let type, let style):
      switch type {
      case .straightLength:
        return StraightLengthField()
      case .group:
        // FIX:
        return GroupField(style: style ?? .supply)
      }

    case .update(let id, let form):
      _ = try await database.effectiveLength.update(id, .init(form: form, projectID: projectID))
      return ProjectView(projectID: projectID, activeTab: .equivalentLength)

    case .submit(let step):
      switch step {
      case .one(let stepOne):
        var effectiveLength: EffectiveLength? = nil
        if let id = stepOne.id {
          effectiveLength = try await database.effectiveLength.get(id)
        }
        return EffectiveLengthForm.StepTwo(
          projectID: projectID,
          stepOne: stepOne,
          effectiveLength: effectiveLength
        )
      case .two(let stepTwo):
        request.logger.debug("ViewController: Got step two...")
        var effectiveLength: EffectiveLength? = nil
        if let id = stepTwo.id {
          effectiveLength = try await database.effectiveLength.get(id)
        }
        return EffectiveLengthForm.StepThree(
          projectID: projectID, effectiveLength: effectiveLength, stepTwo: stepTwo
        )
      case .three(let stepThree):
        request.logger.debug("ViewController: Got step three: \(stepThree)")
        try stepThree.validate()
        _ = try await database.effectiveLength.create(.init(form: stepThree, projectID: projectID))
        return ProjectView(projectID: projectID, activeTab: .equivalentLength)

      }
    }

  }
}

extension SiteRoute.View.ProjectRoute.DuctSizingRoute {

  func renderView(on request: ViewController.Request, projectID: Project.ID) async throws
    -> AnySendableHTML
  {
    @Dependency(\.database) var database
    @Dependency(\.manualD) var manualD

    switch self {
    case .index:
      return request.view {
        ProjectView(projectID: projectID, activeTab: .ductSizing, logger: request.logger)
      }

    case .deleteRectangularSize(let roomID, let rectangularSizeID):
      let room = try await database.rooms.deleteRectangularSize(roomID, rectangularSizeID)
      let container = try await manualD.calculate(
        rooms: [room],
        designFrictionRateResult: database.designFrictionRate(projectID: projectID),
        projectSHR: database.projects.getSensibleHeatRatio(projectID)
      ).first!
      return DuctSizingView.RoomRow(projectID: projectID, room: container)

    case .roomRectangularForm(let roomID, let form):
      let _ = try await database.rooms.update(
        roomID,
        .init(rectangularSizes: [.init(register: form.register, height: form.height)])
      )
      // request.logger.debug("Got room rectangular form: \(roomID)")
      //
      // let containers = try await manualD.calculate(
      //   rooms: [room],
      //   designFrictionRateResult: database.designFrictionRate(projectID: projectID),
      //   projectSHR: database.projects.getSensibleHeatRatio(projectID)
      // )
      // request.logger.debug("Room Containers: \(containers)")
      // let container = containers.first(where: { $0.roomName == "\(room.name)-\(form.register)" })!
      // request.logger.debug("Room Container: \(container)")
      // return DuctSizingView.RoomRow(projectID: projectID, room: container)
      return ProjectView(projectID: projectID, activeTab: .ductSizing, logger: request.logger)
    }
  }
}

private func _render<C: HTML>(
  isHtmxRequest: Bool,
  active activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab = .rooms,
  showSidebar: Bool = true,
  @HTMLBuilder inner: () async throws -> C
) async throws -> AnySendableHTML where C: Sendable {
  let inner = try await inner()
  if isHtmxRequest {
    return inner
  }
  return MainPage { inner }
}

private func _render<C: HTML>(
  isHtmxRequest: Bool,
  active activeTab: SiteRoute.View.ProjectRoute.DetailRoute.Tab = .rooms,
  showSidebar: Bool = true,
  @HTMLBuilder inner: () -> C
) -> AnySendableHTML where C: Sendable {
  let inner = inner()
  if isHtmxRequest {
    return inner
  }
  return MainPage { inner }
}
