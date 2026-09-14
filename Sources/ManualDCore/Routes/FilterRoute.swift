import CasePathsCore
import Foundation
@preconcurrency import URLRouting

extension SiteRoute.View.UserRoute {
  public enum FilterRoute: Equatable, Sendable {
    case index(FilterQuery)
    case editor(id: String?, duplicate: String?)
    case update(FilterLibrary.Change)
    case preview(FilterChartPreview)

    public static let router = OneOf {
      Route(.case(Self.editor)) {
        Path { "editor" }
        Method.get
        Query {
          Optionally { Field("id", .string) }
          Optionally { Field("duplicate", .string) }
        }
      }
      Route(.case(Self.preview)) {
        Path { "preview" }
        Method.post
        Body(.json(FilterChartPreview.self))
      }
      Route(.case(Self.update)) {
        Method.post
        Body(.json(FilterLibrary.Change.self))
      }
      Route(.case(Self.index)) {
        Method.get
        Query {
          Field("tab", .string, default: "library")
          Field("airflow", default: 1200) { Int.parser() }
          Field("q", .string, default: "")
          Field("scope", .string, default: "all")
        }.map(.memberwise(FilterQuery.init))
      }
    }
  }
}

public struct FilterQuery: Equatable, Sendable {
  public var tab: String
  public var airflow: Int
  public var q: String
  public var scope: String
  public init(tab: String = "library", airflow: Int = 1200, q: String = "", scope: String = "all") {
    self.tab = tab
    self.airflow = airflow
    self.q = q
    self.scope = scope
  }
}
public struct FilterChartPreview: Codable, Equatable, Sendable {
  public let filter: AirFilter
  public let airflow: Int
  public init(filter: AirFilter, airflow: Int) {
    self.filter = filter
    self.airflow = airflow
  }
}
