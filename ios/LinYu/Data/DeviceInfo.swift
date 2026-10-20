import Foundation
import LinYuCore

/// `/device/info/mac` 返回的设备台账。
///
/// 字段一律按可选 + 宽容类型解码：服务端在不同学校给的字段并不齐，
/// 少一个字段不该让整页报"查询失败"。
struct DeviceInfo: Decodable, Equatable {
    let deviceId: LossyString?
    let deviceName: String?
    let snCode: String?
    let macAddress: String?
    let withholdMoney: LossyDouble?
    let bigTypeId: LossyString?
    let bigTypeName: String?
    let smallTypeId: LossyString?
    let isBle: Bool?
    let realMac: String?

    var rawName: String {
        if let deviceName, !deviceName.isEmpty { return deviceName }
        if let snCode, !snCode.isEmpty { return snCode }
        return "未知设备"
    }

    var displayName: String {
        DeviceName.formatted(rawName)
    }

    var kind: DeviceKind {
        DeviceKind.resolve(
            deviceName: rawName,
            // 注意：`bigTypeId?.value.flatMap { … }` 会被解析成 String 的 Sequence.flatMap，
            // 必须在 Optional 上 flatMap。
            bigTypeId: bigTypeId.flatMap { Int($0.value) },
            bigTypeName: bigTypeName
        )
    }

    /// 预扣金额，单位是**元**（不是分、也不是厘，别套 `MilliMoney.yuan(fromMilli:)`）
    var withholdMoneyText: String {
        MilliMoney.withSymbol(withholdMoney?.value ?? 0)
    }

    /// 服务端明确标记的蓝牙表。当前多数学校不下发这个字段，取不到就当 false。
    var needsBluetoothControl: Bool { isBle == true }

    /// 明文给用户看的 MAC（优先真实 MAC）
    var displayMac: String {
        if let realMac, !realMac.isEmpty { return realMac }
        if let macAddress, !macAddress.isEmpty { return macAddress }
        return "—"
    }
}
