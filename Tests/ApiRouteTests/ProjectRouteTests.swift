import Dependencies
import Foundation
import ManualDCore
import Testing
import URLRouting

@Suite("ProjectRouteTests")
struct ProjectRouteTests {
  let router = SiteRoute.Api.router

  @Test
  func create() throws {
    let json = """
      {
        \"name\": \"Test\",
        \"streetAddress\": \"1234 Seasme Street\",
        \"city\": \"Nowhere\",
        \"state\": \"OH\",
        \"zipCode\": \"55555\"
      }
      """
    var request = URLRequestData(
      method: "POST",
      path: "/api/v1/projects",
      body: .init(json.utf8)
    )
    let route = try router.parse(&request)
    #expect(
      route
        == .project(
          .create(
            .init(
              name: "Test",
              streetAddress: "1234 Seasme Street",
              city: "Nowhere",
              state: "OH",
              zipCode: "55555"
            )
          )
        )
    )
  }

  @Test
  func delete() throws {
    let id = UUID(0)
    var request = URLRequestData(
      method: "DELETE",
      path: "/api/v1/projects/\(id)"
    )
    let route = try router.parse(&request)
    #expect(route == .project(.delete(id: id)))
  }

  @Test
  func get() throws {
    let id = UUID(0)
    var request = URLRequestData(
      method: "GET",
      path: "/api/v1/projects/\(id)"
    )
    let route = try router.parse(&request)
    #expect(route == .project(.get(id: id)))
  }

  @Test
  func index() throws {
    var request = URLRequestData(
      method: "GET",
      path: "/api/v1/projects"
    )
    let route = try router.parse(&request)
    #expect(route == .project(.index))
  }

  @Test
  func formData() throws {
    let p = Body {
      FormData {
        Optionally {
          Field("id", default: nil) { EffectiveLength.ID.parser() }
        }
        Field("name", .string)
        Field("type") { EffectiveLength.EffectiveLengthType.parser() }
        Many {
          Field("straightLengths") {
            Int.parser()
          }
        }
      }
      .map(.memberwise(SiteRoute.View.ProjectRoute.EquivalentLengthRoute.StepTwo.init))
    }

    var request = URLRequestData(
      body: .init(
        "name=Test&type=supply&straightLengths=20&straightLengths=10"
          .utf8
      )
    )
    let value = try p.parse(&request)
    print(value)
    #expect(value.straightLengths == [20, 10])
  }
}
