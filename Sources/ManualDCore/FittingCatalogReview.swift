import Foundation

extension Fitting {
  public struct CatalogReview: Sendable {
    public let version: String
    public let entries: [CatalogReviewEntry]
    public init(version: String, entries: [CatalogReviewEntry]) {
      self.version = version
      self.entries = entries
    }
  }

  public struct CatalogReviewEntry: Sendable {
    public let id: ID
    public let groupID: Group.ID
    public let groupTitle: String
    public let name: String
    public let sourceCode: SourceCode?
    public let artwork: Artwork
    public let ductShape: Shape
    public let reviewed: Bool
    public init(
      id: ID, groupID: Group.ID, groupTitle: String, name: String,
      sourceCode: SourceCode?, artwork: Artwork, ductShape: Shape, reviewed: Bool
    ) {
      self.id = id
      self.groupID = groupID
      self.groupTitle = groupTitle
      self.name = name
      self.sourceCode = sourceCode
      self.artwork = artwork
      self.ductShape = ductShape
      self.reviewed = reviewed
    }
  }

  public struct CatalogReviewSave: Codable, Sendable {
    public let version: String
    public let changes: [CatalogReviewChange]
    public init(version: String, changes: [CatalogReviewChange]) {
      self.version = version
      self.changes = changes
    }
  }

  public struct CatalogReviewChange: Codable, Sendable {
    public let id: ID
    public let ductShape: Shape
    public let reviewed: Bool
    public init(id: ID, ductShape: Shape, reviewed: Bool) {
      self.id = id
      self.ductShape = ductShape
      self.reviewed = reviewed
    }
  }
}
