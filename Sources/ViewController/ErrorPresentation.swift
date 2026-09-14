import CSVParser
import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDClient
import ManualDCore
import ProjectClient
import Styleguide

import protocol Vapor.AbortError

/// The write finished, but loading the updated screen failed. Retrying the write may duplicate it.
public struct SavedChangeRefreshError: Error {
  public let underlying: any Error
}

func afterMutation<Content>(
  _ mutation: (() async throws -> Void)?, load: () async throws -> Content
) async throws -> Content {
  try await mutation?()
  do { return try await load() } catch {
    if mutation != nil { throw SavedChangeRefreshError(underlying: error) }
    throw error
  }
}

extension ViewController {
  public static func present(
    _ error: any Error, title: String, reference: String
  ) -> PresentationError {
    if let error = error as? PresentationError { return error }
    if error is AccountCreatedError {
      return .init(
        title: "Account created",
        message:
          "Your account was created, but sign-in could not be completed. Sign in to continue; you do not need to sign up again.",
        reference: reference, status: 500, actions: [.init("Sign in", href: "/login")])
    }
    if error is SavedChangeRefreshError {
      return .init(
        title: "Change saved",
        message:
          "Your change was saved, but the updated page could not be loaded. Reload the page before making this change again.",
        reference: reference, status: 500)
    }
    if let fields = validationFields(error) {
      return .init(
        title: title, message: "Check the following values and try again.", fields: fields)
    }
    if let error = error as? FilterError {
      return .init(title: title, message: error.message)
    }
    if let error = error as? ValidationError {
      return .init(title: title, message: error.message)
    }
    if let error = error as? ManualDError {
      return .init(title: title, message: error.message)
    }
    if let error = error as? CSVParsingError {
      return .init(title: title, message: error.reason)
    }
    if let error = error as? RoomImportError {
      return .init(title: title, message: error.reason)
    }
    if let error = error as? Project.DuctSizingUnavailable {
      return .init(title: title, message: error.localizedDescription)
    }
    if error is EquipmentInfo.Incomplete {
      return .init(
        title: title,
        message:
          "Enter heating airflow, cooling airflow, and external static pressure in Equipment.")
    }
    if error is CoolingLoadError {
      return .init(title: title, message: "Enter a total or sensible cooling load for the room.")
    }
    if let error = error as? PathConflictError {
      return .init(title: title, message: error.message, status: 409)
    }
    if error is PathTemplateConflictError {
      return .init(
        title: title,
        message:
          "This template changed in another tab. Your edits are still here. Duplicate them or reload the saved template.",
        status: 409)
    }
    if error is NotFoundError {
      return .init(
        title: title,
        message: "This item is no longer available. Return to your projects and open it again.",
        status: 404)
    }
    if let error = error as? any AbortError, !(error is DecodingError) {
      let message: String
      switch error.status {
      case .unauthorized:
        return .init(
          title: title,
          message:
            "Your session has ended. Sign in in another tab, then return here and try again.",
          status: 401,
          actions: [.init("Sign in in another tab", href: "/login")])
      case .forbidden, .notFound:
        message = "This page or item is unavailable. Check the address or return to your projects."
      case .payloadTooLarge:
        message =
          "The request is too large. Choose a smaller file or reduce the submitted content. Check the size limit shown on the form."
      case .badRequest, .unprocessableEntity:
        message =
          "Some submitted values could not be read. Check the required fields and number formats, then try again."
      case .conflict:
        message =
          "This item changed since you opened it. Check the saved version before trying again."
      default:
        return .init(
          title: title,
          message:
            "The request could not be completed. Use the error reference when contacting support.",
          reference: reference, status: Int(error.status.code))
      }
      return .init(title: title, message: message, status: Int(error.status.code))
    }

    return .init(
      title: title,
      message:
        "The request could not be completed. Use the error reference when contacting support.",
      reference: reference, status: 500)
  }
}

extension ViewController.Request {
  public func errorPage(_ error: PresentationError) async -> AnySendableHTML {
    await view {
      if let (id, tab) = route.projectLocation {
        @Dependency(\.database) var database
        if let user = try? currentUser(),
          (try? await database.projects.getForUser(id, user.id)) != nil
        {
          let steps = try? await database.projects.getCompletedSteps(id)
          ProjectView(projectID: id, activeTab: tab, completedSteps: steps) {
            ErrorMessage(error)
          }
        } else {
          errorContent(error)
        }
      } else {
        errorContent(error)
      }
    }
  }

  @HTMLBuilder private func errorContent(_ error: PresentationError) -> some HTML & Sendable {
    Navbar()
    div(.class("max-w-3xl mx-auto p-6 space-y-4")) {
      ErrorMessage(error)
      a(.class("link"), .href("/projects")) { "Back to projects" }
    }
  }
}

extension SiteRoute.View {
  public var failureTitle: String {
    switch self {
    case .login: "Could not sign in"
    case .signup: "Could not create your account"
    case .project(.create): "Could not create project"
    case .project(.delete): "Could not delete project"
    case .project(.importPDF): "Could not import project"
    case .project(.detail(_, .rooms(.csv))), .project(.detail(_, .rooms(.pdf))):
      "Could not import rooms"
    case .project(.detail(_, .equipment(.submit))), .project(.detail(_, .equipment(.update))):
      "Could not save equipment"
    case .project(.detail(_, .rooms(.submit))), .project(.detail(_, .rooms(.update))):
      "Could not save room"
    case .project(.detail(_, .rooms(.delete))): "Could not delete room"
    case .project(.detail(_, .pdf)): "Could not export PDF"
    default: "Could not complete request"
    }
  }

  var projectLocation: (Project.ID, SiteRoute.View.ProjectRoute.DetailRoute.Tab)? {
    switch self {
    case .project(.update(let id, _)): return (id, .project)
    case .project(.detail(let id, let detail)):
      let tab: SiteRoute.View.ProjectRoute.DetailRoute.Tab
      switch detail {
      case .index, .pdf: tab = .project
      case .rooms: tab = .rooms
      case .equipment: tab = .equipment
      case .equivalentLength: tab = .equivalentLength
      case .componentLoss, .frictionRate: tab = .frictionRate
      case .ductSizing: tab = .ductSizing
      }
      return (id, tab)
    default: return nil
    }
  }
}
