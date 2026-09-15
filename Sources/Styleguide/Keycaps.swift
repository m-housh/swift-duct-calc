import Elementary

public struct Keycaps: HTML, Sendable {
  let binding: String
  public init(_ binding: String) { self.binding = binding }
  public var body: some HTML {
    span(.class("keycaps")) {
      for key in binding.split(separator: "+") {
        kbd(.class("kbd kbd-sm")) {
          key == "Control" ? "Ctrl" : key == "Meta" ? "Command" : String(key)
        }
      }
    }
  }
}
