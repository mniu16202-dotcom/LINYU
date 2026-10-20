import Foundation

/// 设备类型判定。
///
/// - Important: 判定必须**正向**——只有明确指向饮水机的证据才算饮水机。
///   安卓那边踩过坑：原先用「名字含『热水』且不以热水器/热水表开头」来判饮水机，
///   结果某校的淋浴表叫「热水变--1栋宿舍-11层-1001」，既不以热水器也不以热水表开头，
///   被误判成饮水机，界面上就变成「♨️ 正在接热水」。
///   淋浴设备的名字天然含「热水」，所以任何「含热水且不是某某」的规则都是打地鼠。
public enum DeviceKind: String, Equatable, Sendable {
    case shower
    case sink
    case drinkingHot
    case drinkingCold

    public static func resolve(deviceName: String, bigTypeId: Int?, bigTypeName: String?) -> DeviceKind {
        // ① 服务端大类字段是权威判据，优先信它
        let looksLikeDrinking =
            bigTypeId == 5 ||
            (bigTypeName?.contains("饮") ?? false) ||
            // ② 名称兜底：必须是饮水机独有的词
            deviceName.contains("饮水") ||
            deviceName.contains("直饮") ||
            deviceName.contains("开水机") ||
            deviceName.contains("开水器") ||
            // ③ 「冷水」保留：淋浴设备不会叫这个名字
            deviceName.contains("冷水")

        if looksLikeDrinking {
            let isHot =
                deviceName.contains("热") ||
                deviceName.contains("开水") ||
                (bigTypeName?.contains("热") ?? false)
            return isHot ? .drinkingHot : .drinkingCold
        }
        if deviceName.hasPrefix("洗手台") { return .sink }
        return .shower
    }

    /// 详情弹窗标题用（与安卓 `DeviceDetailDialog` 的 `type` 对齐）
    public var title: String {
        switch self {
        case .shower: return "沐浴"
        case .sink: return "洗漱"
        case .drinkingHot: return "饮水（热水）"
        case .drinkingCold: return "饮水（冷水）"
        }
    }

    public var typeName: String {
        switch self {
        case .shower: return "热水器"
        case .sink: return "洗手台"
        case .drinkingHot, .drinkingCold: return "饮水机"
        }
    }

    /// 「小字」位置的说明，措辞与账单里的设备类型标签保持一致
    public var typeLabel: String {
        switch self {
        case .shower: return "卫生间热水器"
        case .sink: return "洗手台热水器"
        case .drinkingHot: return "直饮水机 · 热水"
        case .drinkingCold: return "直饮水机 · 冷水"
        }
    }

    public var emoji: String {
        switch self {
        case .shower: return "🚿"
        case .sink: return "🪥"
        case .drinkingHot: return "♨️"
        case .drinkingCold: return "❄️"
        }
    }

    /// 使用中状态文案
    public var usingText: String {
        switch self {
        case .shower: return "正在沐浴中"
        case .sink: return "正在洗漱中"
        case .drinkingHot: return "正在接热水"
        case .drinkingCold: return "正在接凉水"
        }
    }

    /// 主按钮文案
    public var startActionTitle: String {
        switch self {
        case .drinkingHot, .drinkingCold: return "开始接水"
        case .shower, .sink: return "开始使用"
        }
    }
}
