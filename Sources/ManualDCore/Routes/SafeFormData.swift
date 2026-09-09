import Foundation
import URLRouting

/// Validate escapes before URLRouting.FormData, which indexes an empty array when
/// decoding a malformed field such as `%ZZ` or `%FF`.
public struct SafeFormData<Fields: Parser>: Parser where Fields.Input == URLRequestData.Fields {
  let parser: URLRouting.FormData<Fields>

  public init(@ParserBuilder<URLRequestData.Fields> build: () -> Fields) {
    parser = URLRouting.FormData(build: build)
  }

  public func parse(_ input: inout Data) throws -> Fields.Output {
    guard let text = String(data: input, encoding: .utf8), text.removingPercentEncoding != nil
    else {
      throw InvalidFormEncoding()
    }
    return try parser.parse(&input)
  }
}

extension SafeFormData: ParserPrinter where Fields: ParserPrinter {
  public func print(_ output: Fields.Output, into input: inout Data) throws {
    try parser.print(output, into: &input)
  }
}

private struct InvalidFormEncoding: Error {}
