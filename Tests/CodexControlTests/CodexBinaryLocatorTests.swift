import XCTest
@testable import CodexControl

final class CodexBinaryLocatorTests: XCTestCase {
    func testResolvedPathEnvironmentIsNonEmpty() {
        let path = CodexBinaryLocator.resolvedPathEnvironment(binaryPath: "/opt/homebrew/bin/codex")
        XCTAssertFalse(path.isEmpty)

        let components = path.split(separator: ":").map(String.init)
        XCTAssertFalse(components.isEmpty)
        XCTAssertTrue(components.contains("/usr/bin") || components.contains("/bin"))
    }

    func testResolvedEnvironmentSetsCodexHomeAndPath() {
        let env = CodexBinaryLocator.resolvedEnvironment(codexHome: "/tmp/custom_codex_home", binaryPath: "/usr/local/bin/codex")
        XCTAssertEqual(env["CODEX_HOME"], "/tmp/custom_codex_home")
        XCTAssertNotNil(env["PATH"])
        XCTAssertFalse(env["PATH"]?.isEmpty ?? true)
    }

    func testResolveFindsCodexIfInstalled() {
        if let binary = CodexBinaryLocator.resolve() {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary))
        }
    }
}
