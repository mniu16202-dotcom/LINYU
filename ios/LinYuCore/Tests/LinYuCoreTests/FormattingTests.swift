import XCTest
@testable import LinYuCore

final class FormattingTests: XCTestCase {

    // MARK: - 金额（单位：分）

    func testMoneyFromCents() {
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: 0), "0.00")
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: 5), "0.05")
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: 990), "9.90")
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: 1234), "12.34")
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: 100), "1.00")
    }

    func testMoneyNegative() {
        XCTAssertEqual(MoneyFormat.yuanString(fromCents: -250), "-2.50")
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
