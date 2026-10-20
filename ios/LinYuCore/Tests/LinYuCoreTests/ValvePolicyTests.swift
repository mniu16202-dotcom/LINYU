import XCTest
@testable import LinYuCore

final class ValvePolicyTests: XCTestCase {

    // MARK: - 开阀成功判据

    /// 实测成功就是 state=1 && result=0
    func testOpenedWhenStateOneAndResultZero() {
        XCTAssertTrue(OrderOutcome.isOpened(state: 1, result: 0))
    }

    func testNotOpenedForOtherCombinations() {
        XCTAssertFalse(OrderOutcome.isOpened(state: 0, result: 0), "state==0 是空闲，不是开阀成功")
        XCTAssertFalse(OrderOutcome.isOpened(state: 1, result: 1))
        XCTAssertFalse(OrderOutcome.isOpened(state: nil, result: 0))
        XCTAssertFalse(OrderOutcome.isOpened(state: 6, result: 0), "6 是关阀但有未结账单")
    }

    // MARK: - queryUsing 三态

    func testInUseByOrderNo() {
        XCTAssertEqual(
            UsingState.resolve(errorCode: 0, orderNo: "13200000000000000001", requestFailed: false),
            .inUse(orderNo: "13200000000000000001")
        )
    }

    func testInUseByErrorCode307() {
        XCTAssertEqual(
            UsingState.resolve(errorCode: 307, orderNo: nil, requestFailed: false),
            .inUse(orderNo: "")
        )
    }

    func testIdleWhenNoOrder() {
        XCTAssertEqual(UsingState.resolve(errorCode: 0, orderNo: nil, requestFailed: false), .idle)
        XCTAssertEqual(UsingState.resolve(errorCode: nil, orderNo: "", requestFailed: false), .idle)
    }

    /// 这条是重点：请求失败 ≠ 已经关好了
    func testUnknownWhenRequestFailed() {
        XCTAssertEqual(UsingState.resolve(errorCode: nil, orderNo: nil, requestFailed: true), .unknown)
    }

    func testUnknownForOtherErrorCodes() {
        XCTAssertEqual(UsingState.resolve(errorCode: 1, orderNo: nil, requestFailed: false), .unknown)
        XCTAssertEqual(UsingState.resolve(errorCode: -1, orderNo: nil, requestFailed: false), .unknown)
    }

    func testIsInUse() {
        XCTAssertTrue(UsingState.inUse(orderNo: "x").isInUse)
        XCTAssertFalse(UsingState.idle.isInUse)
        XCTAssertFalse(UsingState.unknown.isInUse)
    }
}
