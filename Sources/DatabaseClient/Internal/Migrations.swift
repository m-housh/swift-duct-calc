import Dependencies
import ManualDCore

extension DatabaseClient.Migrations: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    all: {
      [
        // Use must remain first in the list, otherwise there are postgres errors because the
        // relation doesn't exist when creating tables that reference the user's table.
        User.Migrate(),
        User.Token.Migrate(),
        User.Profile.Migrate(),
        Project.Migrate(),
        ComponentPressureLoss.Migrate(),
        EquipmentInfo.Migrate(),
        Room.Migrate(),
        EquivalentLength.Migrate(),
        TrunkSize.Migrate(),
      ]
    }
  )
}
