import DatabaseClient
import Dependencies
import Logging
import ManualDClient
import ManualDCore

extension ProjectClient: DependencyKey {

  public static var liveValue: Self {
    @Dependency(\.database) var database

    return .init(
      calculateDuctSizes: { projectID in
        try await database.calculateDuctSizes(projectID: projectID)
      }
    )
  }

}
