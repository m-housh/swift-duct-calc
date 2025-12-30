import Foundation
import Vapor

#if DEBUG
  struct BrowserSyncHandler: LifecycleHandler {
    func didBoot(_ application: Application) throws {
      let process = Process()
      process.executableURL = URL(filePath: "/bin/sh")
      process.arguments = ["-c", "browser-sync reload"]
      do {
        try process.run()
      } catch {
        print("Could not auto-reload: \(error)")
      }
    }
  }
#endif
