import XCTest
@testable import LinYuCore

final class ServerErrorTests: XCTestCase {

    func testOfflineDetection() {
        XCTAssertTrue(ServerError(code: 306, message: "").isDeviceOffline)
        XCTAssertFalse(ServerError(code: 307, message: "").isDeviceOffline)
    }

    func testInProgressDetection() {
        XCTAssertTrue(ServerError(code: 307, message: "").isOrderInProgress)
    }

    func testRequiresLoginOn401And403() {
        XCTAssertTrue(ServerError(code: 401, message: "").requiresLogin)
        XCTAssertTrue(ServerError(code: 403, message: "").requiresLogin)
        XCTAssertFalse(ServerError(code: 500, message: "").requiresLogin)
    }

    /// 服务端给的文案优先，没给才回退到内置映射。
    func testDisplayMessagePrefersServerText() {
        XCTAssertEqual(ServerError(code: 306, message: "设备离线").displayMessage, "设备离线")
        XCTAssertEqual(ServerError(code: 306, message: "").displayMessage, "设备不在线（306）")
        XCTAssertEqual(ServerError(code: 170, message: "").displayMessage, "签名校验失败（170）")
    }
}
