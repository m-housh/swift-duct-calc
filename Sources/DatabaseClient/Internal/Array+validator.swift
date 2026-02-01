import Validations

extension Validator {

  static func validate<Child: Validatable>(
    _ toChild: KeyPath<Value, [Child]>
  )
    -> Self
  {
    self.mapValue({ $0[keyPath: toChild] }, with: ArrayValidator())
  }

  static func validate<Child: Validatable>(
    _ toChild: KeyPath<Value, [Child]?>
  )
    -> Self
  {
    self.mapValue({ $0[keyPath: toChild] }, with: ArrayValidator().optional())
  }
}

extension Array where Element: Validatable {
  static func validator() -> some Validation<Self> {
    ArrayValidator<Element>()
  }
}

struct ArrayValidator<Element>: Validation where Element: Validatable {
  func validate(_ value: [Element]) throws {
    for item in value {
      try item.validate()
    }
  }
}

struct ForEachValidator<T, E>: Validation where T: Validation, T.Value == E {
  let validator: T

  init(@ValidationBuilder<E> builder: () -> T) {
    self.validator = builder()
  }

  func validate(_ value: [E]) throws {
    for item in value {
      try validator.validate(item)
    }
  }
}
