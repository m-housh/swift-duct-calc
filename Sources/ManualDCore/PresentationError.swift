import Foundation

/// Safe, actionable information that can be rendered in a page or a failed-request response.
public struct PresentationError: Error, Codable, Equatable, Sendable {
  public struct Action: Codable, Equatable, Sendable {
    public var label: String
    public var href: String

    public init(_ label: String, href: String) {
      self.label = label
      self.href = href
    }
  }
  public struct Field: Codable, Equatable, Sendable {
    public var name: String
    public var message: String

    public init(_ name: String, _ message: String) {
      self.name = name
      self.message = message
    }
  }

  public var title: String
  public var message: String
  public var fields: [Field]
  public var actions: [Action]
  public var reference: String?
  public var status: Int

  public init(
    title: String, message: String, fields: [Field] = [], reference: String? = nil,
    status: Int = 422, actions: [Action] = []
  ) {
    self.title = title
    self.message = message
    self.fields = fields
    self.actions = actions
    self.reference = reference
    self.status = status
  }
}

extension PresentationError: LocalizedError {
  public var errorDescription: String? { message }
}
