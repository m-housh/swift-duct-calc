import Foundation

extension Project {
  public struct PDFUpload: Equatable, Sendable {
    public let file: Data
    public let confirmDuplicate: Bool
    public let zipCode: String?
    /// Replaces the report's project name, chosen when resolving a duplicate.
    public let name: String?

    public init(file: Data) {
      self.init(file: file, confirmDuplicate: false)
    }

    public init(file: Data, confirmDuplicate: Bool, zipCode: String? = nil, name: String? = nil) {
      self.file = file
      self.confirmDuplicate = confirmDuplicate
      self.zipCode = zipCode
      self.name = name
    }
  }

  public struct ImportConflict: Error, Sendable {
    public let projects: [Project]
    /// The report's name with the first numbered suffix not used by the user's projects.
    public let suggestedName: String

    public init(projects: [Project], suggestedName: String) {
      self.projects = projects
      self.suggestedName = suggestedName
    }
  }

  public struct PDFImport: Equatable, Sendable {
    public let project: Project.Create
    public let rooms: [Room.Create]

    public init(project: Project.Create, rooms: [Room.Create]) {
      self.project = project
      self.rooms = rooms
    }
  }
}
