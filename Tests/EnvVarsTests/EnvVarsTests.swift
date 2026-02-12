import Dependencies
import EnvVars
import FileClient
import Foundation
import Testing

@Suite
struct EnvVarsTests {

  let envDict = [
    "PANDOC_PATH": "/custom/path",
    "PDF_ENGINE": "custom-engine",
    "POSTGRES_HOSTNAME": "host",
    "POSTGRES_USER": "ductcalc",
    "POSTGRES_PASSWORD": "secret",
    "POSTGRES_DB": "ductcalc",
    "SQLITE_PATH": "ductcalc.sqlite",
  ]

  @Test
  func fromDict() async throws {

    try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(filePath: $0)) }
    } operation: {
      let sut = try await EnvVars.live(envDict)
      let expected = EnvVars(
        pandocPath: "/custom/path",
        pdfEngine: "custom-engine",
        postgresHostname: "host",
        postgresUsername: "ductcalc",
        postgresPassword: "secret",
        postgresDatabase: "ductcalc",
        sqlitePath: "ductcalc.sqlite"
      )
      #expect(sut.pandocPath == expected.pandocPath)
      #expect(sut.pdfEngine == expected.pdfEngine)
      #expect(sut.postgresHostname == expected.postgresHostname)
      #expect(sut.postgresUsername == expected.postgresUsername)
      #expect(sut.postgresPassword == expected.postgresPassword)
      #expect(sut.postgresDatabase == expected.postgresDatabase)
      #expect(sut.sqlitePath == expected.sqlitePath)
    }
  }

  @Test
  func testLoadingFromFiles() async throws {
    try await withDependencies {
      $0.fileClient.readFile = { try Data(contentsOf: URL(filePath: $0)) }
    } operation: {
      let dbPath = Bundle.module.path(forResource: "db_test", ofType: "txt")
      let passwordPath = Bundle.module.path(forResource: "password_test", ofType: "txt")
      let usernamePath = Bundle.module.path(forResource: "username_test", ofType: "txt")

      var envDict = self.envDict
      envDict["POSTGRES_DB_FILE"] = dbPath!
      envDict["POSTGRES_PASSWORD_FILE"] = passwordPath!
      envDict["POSTGRES_USER_FILE"] = usernamePath!

      // Ensure that it prefer's a value from file, if there's already one set.
      let sut = try await EnvVars.live(
        envDict
      )
      #expect(sut.postgresDatabase == "db-from-file")
      #expect(sut.postgresPassword == "secret-from-file")
      #expect(sut.postgresUsername == "username-from-file")
    }
  }
}
