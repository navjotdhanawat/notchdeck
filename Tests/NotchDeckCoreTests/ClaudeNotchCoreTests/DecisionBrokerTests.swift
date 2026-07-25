import XCTest
@testable import NotchDeckCore

final class DecisionBrokerTests: XCTestCase {
    private func req(_ id: String) -> DecisionRequest {
        DecisionRequest(id: id, sessionKey: "S", kind: .planApproval(text: "p"),
                        receivedAt: Date(timeIntervalSince1970: 1))
    }

    func testResolveReturnsDecision() async {
        let broker = DecisionBroker(timeout: 100)
        async let decided = broker.decide(req("r1"))
        try? await Task.sleep(nanoseconds: 20_000_000)  // let decide register
        await broker.resolve(id: "r1", .allow(scope: .session))
        let got = await decided
        XCTAssertEqual(got, .allow(scope: .session))
    }

    func testTimeoutReturnsPassthrough() async {
        let broker = DecisionBroker(timeout: 0.05)
        let got = await broker.decide(req("r2"))
        XCTAssertEqual(got, .passthrough)
    }

    func testPendingReflectsInFlight() async {
        let broker = DecisionBroker(timeout: 100)
        async let decided = broker.decide(req("r3"))
        try? await Task.sleep(nanoseconds: 20_000_000)
        let pending = await broker.snapshotPending()
        XCTAssertEqual(pending.map(\.id), ["r3"])
        await broker.resolve(id: "r3", .deny(reason: nil))
        _ = await decided
        let after = await broker.snapshotPending()
        XCTAssertTrue(after.isEmpty)
    }
}
