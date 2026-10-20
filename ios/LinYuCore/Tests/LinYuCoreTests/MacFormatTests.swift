import XCTest
@testable import LinYuCore

final class MacFormatTests: XCTestCase {

    /// 实测值（南京理工大学紫金学院，2026-10-03）：
    /// 广播 `C0:15:83:04:D3:00` ↔ 台账 `00:15:83:04:D3:00`
    func testPublicAddressStripsTopTwoBits() {
        XCTAssertEqual(MacFormat.publicAddress(of: "C0:15:83:04:D3:00"), "00158304D300")
        XCTAssertEqual(MacFormat.publicAddress(of: "C0158304D300"), "00158304D300")
    }

    func testPublicAddressReturnsNilForAlreadyPublicAddress() {
        XCTAssertNil(MacFormat.publicAddress(of: "00158304D300"))
    }

    func testConnectAddressRaisesTopTwoBits() {
        XCTAssertEqual(MacFormat.connectAddress(for: "00158304D300"), "C0158304D300")
    }

    func testConnectAddressIsIdentityWhenAlreadyRaised() {
        XCTAssertEqual(MacFormat.connectAddress(for: "C0158304D300"), "C0158304D300")
    }

    /// 顺序是有意义的：原样必须在第一位，否则每次扫码都多一次请求。
    func testLookupVariantsKeepsRawValueFirst() {
        let variants = MacFormat.lookupVariants(for: "C0:15:83:04:D3:00")
        XCTAssertEqual(variants.count, 2)
        XCTAssertEqual(variants[0], "C0:15:83:04:D3:00")
        XCTAssertEqual(variants[1], "00158304d300")
    }

    func testLookupVariantsSingleCandidateForPublicAddress() {
        XCTAssertEqual(MacFormat.lookupVariants(for: "00158304D300"), ["00158304D300"])
    }

    func testNormalizeRejectsNonMac() {
        XCTAssertNil(MacFormat.normalize("hello"))
        XCTAssertNil(MacFormat.normalize("C0158304D30"))
        XCTAssertNil(MacFormat.normalize(""))
    }

    func testNormalizeHandlesLowercaseAndSeparators() {
        XCTAssertEqual(MacFormat.normalize("c0-15-83-04-d3-00"), "C0158304D300")
    }
}
