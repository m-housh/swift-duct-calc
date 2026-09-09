import Dependencies
import DependenciesMacros
import EnvVars
import Foundation
import ManualDCore

#if canImport(Glibc)
  import Glibc
#else
  import Darwin
#endif

extension DependencyValues {
  public var pdfImport: PdfImportClient {
    get { self[PdfImportClient.self] }
    set { self[PdfImportClient.self] = newValue }
  }
}

@DependencyClient
public struct PdfImportClient: Sendable {
  public var parseProject: @Sendable (Room.PDF) async throws -> Project.PDFImport
  public var parseRooms: @Sendable (Room.PDF) async throws -> Room.LoadImport
}

extension PdfImportClient: DependencyKey {
  public static let testValue = Self()

  public static let liveValue = Self(
    parseProject: { try CoolCalcParser.parseProject(await readPDF($0)) },
    parseRooms: { try CoolCalcParser.parse(await readPDF($0)) }
  )
}

private func readPDF(_ pdf: Room.PDF) async throws -> String {
  @Dependency(\.environment) var environment
  let executable = environment.pdfToTextPath
  guard pdf.file.count <= 10 * 1024 * 1024 else {
    throw RoomImportError("Choose a PDF smaller than 10 MB.")
  }
  guard pdf.file.starts(with: Data("%PDF-".utf8)) else {
    throw RoomImportError("Choose a PDF exported from Cool Calc.")
  }
  guard extractionSlots.wait(timeout: .now()) == .success else {
    throw RoomImportError("PDF import is busy. Please try again in a moment.")
  }
  // Run the blocking subprocess and file operations away from Swift's cooperative executor.
  let text: String = try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global(qos: .userInitiated).async {
      defer { extractionSlots.signal() }
      continuation.resume(with: Result { try extractText(pdf.file, executable: executable) })
    }
  }
  try Task.checkCancellation()
  return text
}

// Bound active subprocesses and reject excess work instead of retaining an unbounded upload queue.
private let extractionSlots = DispatchSemaphore(value: 4)

func extractText(
  _ data: Data, executable: String, timeout: Double = 20, maximumBytes: Int = 5 * 1024 * 1024
) throws -> String {
  guard FileManager.default.isExecutableFile(atPath: executable) else {
    throw RoomImportError(
      "PDF import is unavailable. The server needs Poppler's pdftotext installed.")
  }
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("room-import-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(
    at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
  defer { try? FileManager.default.removeItem(at: directory) }
  let input = directory.appendingPathComponent("report.pdf")
  try data.write(to: input)

  let process = Process()
  let output = Pipe()
  let arguments = ["-layout", "-enc", "UTF-8", "-l", "201", input.path, "-"]
  #if os(Linux)
    // Limit the parser's own allocations as well as the text we retain in this process.
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/prlimit") else {
      throw RoomImportError(
        "PDF import is unavailable. The server needs util-linux's prlimit installed.")
    }
    process.executableURL = URL(fileURLWithPath: "/usr/bin/prlimit")
    process.arguments = ["--as=536870912", "--cpu=20", "--core=0", "--", executable] + arguments
  #else
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
  #endif
  process.standardOutput = output
  process.standardError = FileHandle.nullDevice
  defer { try? output.fileHandleForReading.close() }
  try process.run()
  // A watchdog also covers a child that never writes anything to stdout.
  let watchdog = DispatchWorkItem {
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
  }
  DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)
  defer {
    watchdog.cancel()
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    process.waitUntilExit()
  }
  var bytes = Data()
  while let chunk = try output.fileHandleForReading.read(upToCount: 8192), !chunk.isEmpty {
    guard bytes.count + chunk.count <= maximumBytes else {
      throw RoomImportError("This PDF contains too much text to import.")
    }
    bytes.append(chunk)
  }
  process.waitUntilExit()
  if process.terminationReason == .uncaughtSignal && process.terminationStatus == SIGKILL {
    throw RoomImportError("PDF import took too long. Try a smaller Cool Calc report.")
  }
  guard process.terminationStatus == 0, let text = String(data: bytes, encoding: .utf8) else {
    throw RoomImportError(
      "Could not read this PDF. Export an unlocked report from Cool Calc and try again.")
  }
  guard text.filter({ $0 == "\u{000C}" }).count <= 200 else {
    throw RoomImportError("Choose a Cool Calc report with at most 200 pages.")
  }
  return text
}
