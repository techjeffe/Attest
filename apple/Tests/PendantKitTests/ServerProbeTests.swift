import XCTest
@testable import PendantKit

final class ServerProbeTests: XCTestCase {
    func testNormalizeAddsHttps() {
        XCTAssertEqual(ServerProbe.normalize("attest.example.com"), "https://attest.example.com")
        XCTAssertEqual(ServerProbe.normalize("  https://a.b  "), "https://a.b")
        XCTAssertEqual(ServerProbe.normalize("localhost:8787"), "http://localhost:8787")
        XCTAssertEqual(ServerProbe.normalize(""), "")
    }

    func testClassify() {
        XCTAssertEqual(ServerProbe.classify(status: 200, finalHost: "a.com", expectedHost: "a.com", body: "<title>Attest</title>"), .ok)
        XCTAssertEqual(ServerProbe.classify(status: 200, finalHost: "a.com", expectedHost: "a.com", body: "<title>Welcome to nginx</title>"), .notAttest)
        XCTAssertEqual(ServerProbe.classify(status: 200, finalHost: "team.cloudflareaccess.com", expectedHost: "a.com", body: "Sign in"), .needsSignIn)
        XCTAssertEqual(ServerProbe.classify(status: 403, finalHost: "a.com", expectedHost: "a.com", body: ""), .needsSignIn)
        XCTAssertEqual(ServerProbe.classify(status: 404, finalHost: "a.com", expectedHost: "a.com", body: ""), .notAttest)
    }
}
