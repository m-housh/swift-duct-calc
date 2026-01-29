import Dependencies
import ManualDCore

extension DatabaseClient.Migrations: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    all: {
      [
        Project.Migrate(),
        User.Migrate(),
        User.Token.Migrate(),
        User.Profile.Migrate(),
        ComponentPressureLoss.Migrate(),
        EquipmentInfo.Migrate(),
        Room.Migrate(),
        EquivalentLength.Migrate(),
        TrunkSize.Migrate(),
      ]
    }
  )
}
