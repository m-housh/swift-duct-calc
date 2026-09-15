import DatabaseClient
import Dependencies
import Elementary
import Foundation
import ManualDCore

extension SiteRoute.View.UserRoute.KeybindingsRoute {
  func renderView(on request: ViewController.Request) async throws -> AnySendableHTML {
    let user = try request.currentUser()
    switch self {
    case .index:
      return await request.view { KeybindingsView(bindings: user.keybindings ?? .init()) }
    case .save(let payload):
      @Dependency(\.database.users) var users
      do {
        let input: Keybindings
        do { input = try JSONDecoder().decode(Keybindings.self, from: Data(payload.utf8)) } catch {
          throw KeybindingError("Choose valid key combinations and try saving again.")
        }
        let bindings = try await users.saveKeybindings(user.id, input)
        return MainPage(
          theme: await request.profile?.theme ?? .default, keybindings: bindings,
          title: "Keybindings · Duct Calc"
        ) {
          KeybindingsView(bindings: bindings, saved: true)
        }
      } catch let error as KeybindingError {
        throw PresentationError(title: "Could not save keybindings", message: error.message)
      }
    }
  }
}

func keybindingsJSON<T: Encodable>(_ value: T) -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  return String(decoding: try! encoder.encode(value), as: UTF8.self)
}
