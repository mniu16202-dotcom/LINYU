import XCTest
@testable import LinYuCore

final class DeviceTests: XCTestCase {

    // MARK: - 显示名格式化

    func testFormattedShowerName() {
        XCTAssertEqual(
            DeviceName.formatted("热水器-学生公寓-1号楼-3层-301"),
            "学生公寓 1号楼 301"
        )
    }

    /// 某校真实命名：既不以「热水器」也不以「热水表」开头
    func testFormattedHandlesHotWaterVariant() {
        XCTAssertEqual(
            DeviceName.formatted("热水变--1栋宿舍-11层-1001"),
            "1栋宿舍 1001"
        )
    }

    func testFormattedSinkName() {
        XCTAssertEqual(
            DeviceName.formatted("洗手台54-龙川北苑-3号楼南-3层-320洗手台"),
            "龙川北苑 3号楼南 320房"
        )
    }

    func testFormattedDrinkingWaterName() {
        XCTAssertEqual(
            DeviceName.formatted("直饮冷水-1栋-1层-101"),
            "1栋 101"
        )
    }

    /// 规则全部剥完为空时要回退原名，不能显示空字符串
    func testFormattedFallsBackToOriginal() {
        XCTAssertEqual(DeviceName.formatted("热水表"), "热水表")
    }

    // MARK: - 类型判定

    /// 这是安卓那边真实踩过的坑：误判成饮水机后界面显示「正在接热水」
    func testHotWaterVariantIsNotDrinkingWater() {
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "热水变--1栋宿舍-11层-1001", bigTypeId: nil, bigTypeName: nil),
            .shower
        )
    }

    func testSinkDetection() {
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "洗手台54-龙川北苑-3号楼南-3层-320洗手台", bigTypeId: nil, bigTypeName: nil),
            .sink
        )
    }

    func testDrinkingWaterByServerType() {
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "某设备-1层-101", bigTypeId: 5, bigTypeName: nil),
            .drinkingCold
        )
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "开水机-1层-101", bigTypeId: nil, bigTypeName: nil),
            .drinkingHot
        )
    }

    func testDrinkingWaterByName() {
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "直饮冷水-1栋-1层-101", bigTypeId: nil, bigTypeName: nil),
            .drinkingCold
        )
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "直饮热水-1栋-1层-101", bigTypeId: nil, bigTypeName: nil),
            .drinkingHot
        )
    }

    func testPlainShowerIsShower() {
        XCTAssertEqual(
            DeviceKind.resolve(deviceName: "热水表-1栋-3层-320", bigTypeId: nil, bigTypeName: nil),
            .shower
        )
    }

    // MARK: - 二维码解析

    func testQrCodeParsesDeviceCode() {
        XCTAssertEqual(
            QRPayload.deviceCode(from: "KLCXKJ-Water,M,AABBCCDDEEFF"),
            "AABBCCDDEEFF"
        )
    }

    func testQrCodeIsCaseInsensitiveAndToleratesColons() {
        XCTAssertEqual(
            QRPayload.deviceCode(from: "klcxkj-water,m,c0:15:83:04:d3:00"),
            "C0158304D300"
        )
    }

    func testQrCodeRejectsForeignCodes() {
        XCTAssertNil(QRPayload.deviceCode(from: "https://example.com/pay?x=1"))
        XCTAssertNil(QRPayload.deviceCode(from: "KLCXKJ-Water,M,ZZ"))
        XCTAssertNil(QRPayload.deviceCode(from: ""))
    }
}
