import Dependencies
import Elementary
import EnvVars
import FileClient
import Foundation
import PdfClient
import Testing

struct PdfExportTests {
  @Test(arguments: [0, 7, 8])
  func converterUsesTemporaryFilesAndReportsFailures(status: Int) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let executable = directory.appendingPathComponent("converter")
    let script = """
      #!/bin/sh
      test "$PWD" != "\(FileManager.default.currentDirectoryPath)" || exit 91
      probe=$(mktemp ./pdf-check.XXXXXX) || exit 92
      rm "$probe"
      for argument in "$@"; do
        case "$argument" in
          --css=*) test -r "${argument#--css=}" || exit 93 ;;
          --output=*) output="${argument#--output=}" ;;
        esac
      done
      if [ \(status) -ne 8 ]; then printf '%%PDF-1.4\\n' > "$output"; fi
      if [ \(status) -eq 7 ]; then exit 7; fi
      """
    try script.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    let files = ExportFiles()
    try await withDependencies {
      $0.environment = .init(pandocPath: executable.path)
      $0.fileClient.writeFile = { contents, path in
        await files.record(path)
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
      }
      $0.fileClient.removeFile = { try FileManager.default.removeItem(atPath: $0) }
    } operation: {
      let client = PdfClient.liveValue
      if status == 0 {
        let id = UUID()
        let first = try await client.generatePdf(id, p { "Export" })
        let second = try await client.generatePdf(id, p { "Export" })
        #expect(first.pdfPath != second.pdfPath)
        for result in [first, second] {
          #expect(
            try Data(contentsOf: URL(fileURLWithPath: result.pdfPath)).starts(
              with: Data("%PDF".utf8)))
          try FileManager.default.removeItem(atPath: result.htmlPath)
          try FileManager.default.removeItem(atPath: result.pdfPath)
        }
      } else {
        await #expect(throws: status == 7 ? PdfGenerationError.conversionFailed(7) : .missingOutput)
        {
          try await client.generatePdf(UUID(), p { "Export" })
        }
        for path in await files.paths {
          #expect(!FileManager.default.fileExists(atPath: path))
          #expect(!FileManager.default.fileExists(atPath: String(path.dropLast(5)) + ".pdf"))
        }
      }
    }
  }
}

private actor ExportFiles {
  var paths: [String] = []
  func record(_ path: String) { paths.append(path) }
}
