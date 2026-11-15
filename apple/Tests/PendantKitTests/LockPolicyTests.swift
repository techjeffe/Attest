import XCTest
@testable import PendantKit

final class LockPolicyTests: XCTestCase {
    func testNeedsUnlock() {
        let t = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(LockPolicy.needsUnlock(enabled: false, leftAt: nil, now: t), "lock off: never")
        XCTAssertTrue(LockPolicy.needsUnlock(enabled: true, leftAt: nil, now: t), "no record of leaving: ask")
        XCTAssertFalse(LockPolicy.needsUnlock(enabled: true, leftAt: t.addingTimeInterval(-10), now: t), "a quick glance away")
        XCTAssertTrue(LockPolicy.needsUnlock(enabled: true, leftAt: t.addingTimeInterval(-30), now: t), "at the grace limit")
        XCTAssertTrue(LockPolicy.needsUnlock(enabled: true, leftAt: t.addingTimeInterval(-3600), now: t))
    }
}
