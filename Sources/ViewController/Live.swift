import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore
import Styleguide

extension ViewController.Request {

  func render() async -> AnySendableHTML {

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
        return view {
          LoginForm(style: .signup)
        }
      case .submit(let request):
        // Create a new user and log them in.
        return await view {
          await ResultView {
            let user = try await createAndAuthenticate(request)
            return (
              user.id,
              try await database.projects.fetch(user.id, .init(page: 1, per: 25))
            )
          } onSuccess: { (userID, projects) in
            ProjectsTable(userID: userID, projects: projects)
          }
        }
      }
    case .project(let route):
      return await route.renderView(on: self)
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

  func view<C: HTML>(
    @HTMLBuilder inner: () async -> C
  ) async -> AnySendableHTML where C: Sendable {
    await _render(isHtmxRequest: isHtmxRequest, showSidebar: showSidebar) {
      await inner()
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

  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return await request.view {
        await ResultView {
          let user = try request.currentUser()
          return try await (
            user.id,
            database.projects.fetchPage(userID: user.id)
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

    case .form(let id, let dismiss):
      return await ResultView {
        var project: Project? = nil
        if let id, dismiss == false {
          project = try await database.projects.get(id)
        }
        return project
      } onSuccess: { project in
        ProjectForm(dismiss: dismiss, project: project)
      }

    case .create(let form):
      return await ResultView {
        let user = try request.currentUser()
        let project = try await database.projects.create(user.id, form)
        try await database.componentLoss.createDefaults(projectID: project.id)
        return project.id

      } onSuccess: { projectID in
        ProjectView(projectID: projectID, activeTab: .rooms)
      }

    case .delete(let id):
      return await ResultView {
        try await database.projects.delete(id)
      } onSuccess: {
        EmptyHTML()
      }

    case .update(let id, let form):
      return await ResultView {
        try await database.projects.update(id, form).id
      } onSuccess: { projectID in
        return ProjectView(projectID: projectID, activeTab: .project)
      }

    case .detail(let projectID, let route):
      switch route {
      case .index(let tab):
        return request.view {
          ProjectView(projectID: projectID, activeTab: tab)
        }
      case .componentLoss(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .ductSizing(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .equipment(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .equivalentLength(let route):
        return await route.renderView(on: request, projectID: projectID)
      case .frictionRate(let route):
        return route.renderView(on: request, projectID: projectID)
      case .rooms(let route):
        return await route.renderView(on: request, projectID: projectID)
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
      return await ResultView {
        try await database.equipment.fetch(projectID)
      } onSuccess: { equipment in
        EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
      }
    case .form(let dismiss):
      return await ResultView {
        try await database.equipment.fetch(projectID)
      } onSuccess: { equipment in
        EquipmentInfoForm(dismiss: dismiss, projectID: projectID, equipmentInfo: equipment)
      }
    case .submit(let form):
      return await ResultView {
        try await database.equipment.create(form)
      } onSuccess: { equipment in
        EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
      }
    case .update(let id, let updates):
      return await ResultView {
        try await database.equipment.update(id, updates)
      } onSuccess: { equipment in
        EquipmentInfoView(equipmentInfo: equipment, projectID: projectID)
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.RoomRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {

    case .delete(let id):
      return await ResultView {
        try await database.rooms.delete(id)
      }

    case .form(let id, let dismiss):
      return await ResultView {
        var room: Room? = nil
        if let id, dismiss == false {
          room = try await database.rooms.get(id)
        }
        return room
      } onSuccess: { room in
        RoomForm(dismiss: dismiss, projectID: projectID, room: room)
      }

    case .index:
      return request.view {
        ProjectView(projectID: projectID, activeTab: .rooms)
      }

    case .submit(let form):
      return await request.view {
        await ResultView {
          request.logger.debug("New room form submitted.")
          // FIX: Just return a room row??
          let _ = try await database.rooms.create(form)
        } onSuccess: {
          ProjectView(projectID: projectID, activeTab: .rooms)
        }
      }

    case .update(let id, let form):
      return await ResultView {
        let _ = try await database.rooms.update(id, form)
      } onSuccess: {
        ProjectView(projectID: projectID, activeTab: .rooms)
      }

    case .updateSensibleHeatRatio(let form):
      return await request.view {
        await ResultView {
          let _ = try await database.projects.update(
            form.projectID,
            .init(sensibleHeatRatio: form.sensibleHeatRatio)
          )
        } onSuccess: {
          ProjectView(projectID: projectID, activeTab: .rooms)
        }
      }
    }
  }
}

extension SiteRoute.View.ProjectRoute.FrictionRateRoute {
  func renderView(
    on request: ViewController.Request,
    projectID: Project.ID
  ) -> AnySendableHTML {

    switch self {
    case .index:
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
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {
    case .index:
      return EmptyHTML()
    case .delete(let id):
      return await ResultView {
        _ = try await database.componentLoss.delete(id)
      } onSuccess: {
        EmptyHTML()
      }
    // return EmptyHTML()
    case .submit(let form):
      return await ResultView {
        _ = try await database.componentLoss.create(form)
      } onSuccess: {
        ProjectView(projectID: projectID, activeTab: .frictionRate)
      }
    case .update(let id, let form):
      return await ResultView {
        _ = try await database.componentLoss.update(id, form)
      } onSuccess: {
        ProjectView(projectID: projectID, activeTab: .frictionRate)
      }
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
  ) async -> AnySendableHTML {
    @Dependency(\.database) var database

    switch self {

    case .delete(let id):
      return await ResultView {
        try await database.effectiveLength.delete(id)
      }

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
      return await ResultView {
        _ = try await database.effectiveLength.update(id, .init(form: form, projectID: projectID))
      } onSuccess: {
        ProjectView(projectID: projectID, activeTab: .equivalentLength)
      }

    case .submit(let step):
      switch step {
      case .one(let stepOne):
        return await ResultView {
          var effectiveLength: EffectiveLength? = nil
          if let id = stepOne.id {
            effectiveLength = try await database.effectiveLength.get(id)
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
          var effectiveLength: EffectiveLength? = nil
          if let id = stepTwo.id {
            effectiveLength = try await database.effectiveLength.get(id)
          }
          return effectiveLength
        } onSuccess: { effectiveLength in
          return EffectiveLengthForm.StepThree(
            projectID: projectID, effectiveLength: effectiveLength, stepTwo: stepTwo
          )
        }
      case .three(let stepThree):
        return await ResultView {
          request.logger.debug("ViewController: Got step three: \(stepThree)")
          try stepThree.validate()
          _ = try await database.effectiveLength.create(
            .init(form: stepThree, projectID: projectID))
        } onSuccess: {
          ProjectView(projectID: projectID, activeTab: .equivalentLength)
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

    switch self {
    case .index:
      return request.view {
        ProjectView(projectID: projectID, activeTab: .ductSizing, logger: request.logger)
      }

    case .deleteRectangularSize(let roomID, let rectangularSizeID):
      return await ResultView {
        let room = try await database.rooms.deleteRectangularSize(roomID, rectangularSizeID)
        return try await database.calculateDuctSizes(projectID: projectID)
          .filter({ $0.roomID == room.id })
          .first!
      } onSuccess: { container in
        DuctSizingView.RoomRow(projectID: projectID, room: container)
      }

    case .roomRectangularForm(let roomID, let form):
      return await ResultView {
        let room = try await database.rooms.update(
          roomID,
          .init(
            rectangularSizes: [
              .init(id: form.id ?? .init(), register: form.register, height: form.height)
            ]
          )
        )
        return try await database.calculateDuctSizes(projectID: projectID)
          .filter({ $0.roomID == room.id })
          .first!
      } onSuccess: { container in
        DuctSizingView.RoomRow(projectID: projectID, room: container)
      }
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
  @HTMLBuilder inner: () async -> C
) async -> AnySendableHTML where C: Sendable {
  let inner = await inner()
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
