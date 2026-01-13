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
      return await view {
        TestPage()
      }
    case .login(let route):
      switch route {
      case .index(let next):
        return await view {
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
            _ = try await database.userProfile.create(profile)
            let userID = profile.userID
            // let user = try currentUser()
            return (
              userID,
              try await database.projects.fetch(userID, .init(page: 1, per: 25))
            )
          } onSuccess: { (userID, projects) in
            ProjectsTable(userID: userID, projects: projects)
          }
        }
      }
    case .project(let route):
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

    return MainPage(theme: theme) {
      inner
    }
  }

  var theme: Theme? {
    get async {
      @Dependency(\.database) var database
      guard let user = try? currentUser() else { return nil }
      return try? await database.userProfile.fetch(user.id)?.theme
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

    case .create(let form):
      return await ResultView {
        let user = try request.currentUser()
        let project = try await database.projects.create(user.id, form)
        try await database.componentLoss.createDefaults(projectID: project.id)
        let rooms = try await database.rooms.fetch(project.id)
        let shr = try await database.projects.getSensibleHeatRatio(project.id)
        let completedSteps = try await database.projects.getCompletedSteps(project.id)
        return (project.id, rooms, shr, completedSteps)
      } onSuccess: { (projectID, rooms, shr, completedSteps) in
        ProjectView(
          projectID: projectID,
          activeTab: .rooms,
          completedSteps: completedSteps
        ) {
          RoomsView(rooms: rooms, sensibleHeatRatio: shr)
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
    @Dependency(\.database) var database

    switch self {

    case .delete(let id):
      return await ResultView {
        try await database.rooms.delete(id)
      }

    case .index:
      return await roomsView(on: request, projectID: projectID)

    case .submit(let form):
      return await roomsView(on: request, projectID: projectID) {
        _ = try await database.rooms.create(form)
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
        let componentLosses = try await database.componentLoss.fetch(projectID)
        let lengths = try await database.effectiveLength.fetchMax(projectID)

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
            frictionRateResponse: frictionRate
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
        _ = try await database.componentLoss.delete(id)
      }
    case .submit(let form):
      return await view(on: request, projectID: projectID) {
        _ = try await database.componentLoss.create(form)
      }

    case .update(let id, let form):
      return await view(on: request, projectID: projectID) {
        _ = try await database.componentLoss.update(id, form)
      }
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
        try await catching()

        let equipment = try await database.equipment.fetch(projectID)
        let componentLosses = try await database.componentLoss.fetch(projectID)
        let lengths = try await database.effectiveLength.fetchMax(projectID)

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
            frictionRateResponse: frictionRate
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

    switch self {

    case .delete(let id):
      return await ResultView {
        try await database.effectiveLength.delete(id)
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
        _ = try await database.effectiveLength.update(id, .init(form: form, projectID: projectID))
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
        return await view(on: request, projectID: projectID) {
          _ = try await database.effectiveLength.create(
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
          try await database.effectiveLength.fetch(projectID)
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

    switch self {
    case .index:
      return await view(on: request, projectID: projectID)

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
          try await database.calculateDuctSizes(projectID: projectID)
        )
      } onSuccess: { (steps, rooms) in
        ProjectView(projectID: projectID, activeTab: .ductSizing, completedSteps: steps) {
          DuctSizingView(rooms: rooms)
        }
      }
    }
  }
}

extension SiteRoute.View.UserRoute {

  func renderView(on request: ViewController.Request) async -> AnySendableHTML {
    switch self {
    case .profile(let route):
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
        _ = try await database.userProfile.create(form)
      }
    case .update(let id, let updates):
      return await view(on: request) {
        _ = try await database.userProfile.update(id, updates)
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
          try await database.userProfile.fetch(user.id)
        )
      } onSuccess: { (user, profile) in
        UserView(user: user, profile: profile)
      }
    }
  }
}
