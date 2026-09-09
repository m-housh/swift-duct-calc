import Foundation

extension Project {
  public struct PDFUpload: Equatable, Sendable {
    public let file: Data
    public let confirmDuplicate: Bool

    public init(file: Data) {
      self.init(file: file, confirmDuplicate: false)
    }

    public init(file: Data, confirmDuplicate: Bool) {
      self.file = file
      self.confirmDuplicate = confirmDuplicate
    }
  }

  public struct ImportConflict: Error, Sendable {
    public let projects: [Project]

    public init(projects: [Project]) { self.projects = projects }
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
