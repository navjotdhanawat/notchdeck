import XCTest
@testable import NotchDeckCore

final class DecisionEncoderTests: XCTestCase {
    private func obj(_ data: Data) -> [String: Any] {
        (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    func testAllowShape() {
        let d = DecisionEncoder.stdoutJSON(for: .allow(scope: .once))!
        let hs = obj(d)["hookSpecificOutput"] as! [String: Any]
        XCTAssertEqual(hs["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual((hs["decision"] as! [String: Any])["behavior"] as? String, "allow")
    }

    func testDenyIncludesMessage() {
        let d = DecisionEncoder.stdoutJSON(for: .deny(reason: "nope"))!
        let dec = (obj(d)["hookSpecificOutput"] as! [String: Any])["decision"] as! [String: Any]
        XCTAssertEqual(dec["behavior"] as? String, "deny")
        XCTAssertEqual(dec["message"] as? String, "nope")
    }

    func testDenyDefaultMessageWhenNil() {
        let d = DecisionEncoder.stdoutJSON(for: .deny(reason: nil))!
        let dec = (obj(d)["hookSpecificOutput"] as! [String: Any])["decision"] as! [String: Any]
        XCTAssertEqual(dec["behavior"] as? String, "deny")
        XCTAssertNotNil(dec["message"] as? String)
    }

    func testPassthroughIsNil() {
        XCTAssertNil(DecisionEncoder.stdoutJSON(for: .passthrough))
    }
}
