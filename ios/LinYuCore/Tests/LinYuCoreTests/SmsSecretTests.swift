import XCTest
@testable import LinYuCore

final class SmsSecretTests: XCTestCase {

    /// 安卓 `SignUtils.kt` 注释里的例子：13800138000 → MD5("1388000klcx")
    func testSecretMatchesAndroidImplementation() {
        XCTAssertEqual(
            SmsSecret.secret(for: "13800138000"),
            "f000554d9cb90c44bd0ae2ded9a847aa"
        )
    }

    /// `API-qzxy.md` 里的例子：185****3960 → MD5("1853960klcx")
    func testSecretMatchesApiDocumentation() {
        XCTAssertEqual(
            SmsSecret.secret(for: "18500003960"),
            "e3d2220b920cca13499ea76328e24a4e"
        )
    }

    func testRejectsMalformedPhone() {
        XCTAssertNil(SmsSecret.secret(for: "1380013800"))
        XCTAssertNil(SmsSecret.secret(for: "138001380000"))
        XCTAssertNil(SmsSecret.secret(for: "1380013800a"))
        XCTAssertNil(SmsSecret.secret(for: ""))
    }

    func testDigestEmptyString() {
        XCTAssertEqual(Digest.md5Hex(""), "d41d8cd98f00b204e9800998ecf8427e")
    }
}
