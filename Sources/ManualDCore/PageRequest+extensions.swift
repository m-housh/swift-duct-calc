import Fluent

extension PageRequest {

  public static var first: Self {
    .init(page: 1, per: 25)
  }

  public static func next<T>(_ currentPage: Page<T>) -> Self {
    .init(page: currentPage.metadata.page + 1, per: currentPage.metadata.per)
  }
}
