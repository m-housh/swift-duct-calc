/// Account creation succeeded, but the follow-up sign-in failed.
public struct AccountCreatedError: Error {
  public let underlying: any Error

  public init(underlying: any Error) { self.underlying = underlying }
}
