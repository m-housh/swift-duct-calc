import Foundation
import ManualDCore
import Testing

@testable import PdfImportClient

@Suite
struct ExtractionLimitsTests {
  @Test
  func limitsOutputAndRemovesTemporaryUpload() throws {
    try withExecutable("exec /usr/bin/yes x") { executable in
      #expect(throws: RoomImportError("This PDF contains too much text to import.")) {
        try extractText(Data("%PDF-test".utf8), executable: executable, maximumBytes: 1024)
      }
      let input = try String(contentsOfFile: executable + ".input", encoding: .utf8)
      #expect(!FileManager.default.fileExists(atPath: input))
    }
  }

  @Test
  func terminatesSilentExtractorAndRemovesTemporaryUpload() throws {
    try withExecutable("exec /bin/sleep 60") { executable in
      let start = ContinuousClock.now
      #expect(throws: RoomImportError("PDF import took too long. Try a smaller Cool Calc report."))
      {
        try extractText(Data("%PDF-test".utf8), executable: executable, timeout: 0.05)
      }
      #expect(start.duration(to: .now) < .seconds(3))
      let input = try String(contentsOfFile: executable + ".input", encoding: .utf8)
      #expect(!FileManager.default.fileExists(atPath: input))
    }
  }

  private func withExecutable(_ command: String, operation: (String) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let executable = directory.appendingPathComponent("extractor")
    try Data("#!/bin/sh\nprintf '%s' \"$6\" > \"$0.input\"\n\(command)\n".utf8).write(
      to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    try operation(executable.path)
  }
}
