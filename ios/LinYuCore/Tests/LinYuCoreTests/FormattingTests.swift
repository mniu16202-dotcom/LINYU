import XCTest
@testable import LinYuCore

final class FormattingTests: XCTestCase {

    // MARK: - 金额（单位：厘）

    func testMilliToYuan() {
        XCTAssertEqual(MilliMoney.yuan(fromMilli: 40), 0.04, accuracy: 0.0001)
        XCTAssertEqual(MilliMoney.yuan(fromMilli: 1000), 1.0, accuracy: 0.0001)
        XCTAssertEqual(MilliMoney.yuan(fromMilli: 0), 0, accuracy: 0.0001)
    }

    /// 与安卓 `MoneyFormat.format` 一致：3 位小数，末位 0 收敛成 2 位
    func testMoneyFormatting() {
        XCTAssertEqual(MilliMoney.formatted(0.025), "0.025")
        XCTAssertEqual(MilliMoney.formatted(0.04), "0.04")
        XCTAssertEqual(MilliMoney.formatted(0.4), "0.40")
        XCTAssertEqual(MilliMoney.formatted(5.0), "5.00")
        XCTAssertEqual(MilliMoney.formatted(10.15), "10.15")
        XCTAssertEqual(MilliMoney.formatted(0), "0.00")
        XCTAssertEqual(MilliMoney.withSymbol(0.025), "¥0.025")
    }

    // MARK: - 时间

    func testCompactDateParsing() {
        let date = ServerClock.date(fromCompact: "20260918150627")
        XCTAssertNotNil(date)
        guard let date else { return }
        XCTAssertEqual(ServerClock.compact(from: date), "20260918150627")
    }

    func testCompactDateRejectsGarbage() {
        XCTAssertNil(ServerClock.date(fromCompact: "2026-09-18 15:06:27"))
        XCTAssertNil(ServerClock.date(fromCompact: "2026091815062"))
        XCTAssertNil(ServerClock.date(fromCompact: ""))
    }

    func testDurationText() {
        XCTAssertEqual(ServerClock.durationText(seconds: 0), "0秒")
        XCTAssertEqual(ServerClock.durationText(seconds: 45), "45秒")
        XCTAssertEqual(ServerClock.durationText(seconds: 60), "1分0秒")
        XCTAssertEqual(ServerClock.durationText(seconds: 754), "12分34秒")
        XCTAssertEqual(ServerClock.durationText(seconds: -10), "0秒")
    }
}
