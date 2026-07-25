import XCTest
@testable import ClaudeNotchCore

final class BridgeConfigTests: XCTestCase {
    func testRoundTripAndPermissions() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bridge-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let cfg = BridgeConfig(port: 51234, token: "secret-token")
        try BridgeConfigWriter.write(cfg, to: url)
        XCTAssertEqual(try BridgeConfigWriter.read(from: url), cfg)

        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }
}
