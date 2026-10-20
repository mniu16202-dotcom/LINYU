import Foundation

/// 设备名 → 界面显示名。
///
/// 把「热水表-龙川北苑-3号楼南-3层-320房」压成「龙川北苑 3号楼南 320房」。
/// 规则逐个照抄安卓 `DeviceInfo.formatDeviceName`，**顺序不能改**：
/// 必须先剥「热水器/热水表/热水变」，否则后面按「热水」开头的规则会先吃掉"热水"，
/// 把「热水表-xxx」处理成「表 xxx」。
public enum DeviceName {

    /// 显示名。全部规则剥完为空时回退到原名。
    public static func formatted(_ name: String) -> String {
        var text = name

        // 1. 淋浴设备前缀。含「热水变」——某校真这么命名（热水变--1栋宿舍-11层-1001）。
        text = replace("^热水[器表变][- ]*", with: "", in: text)
        // 2. 饮水机前缀
        text = replace("^直饮[- ]*(开水|冷水|热水|温水)[- ]*", with: "", in: text)
        text = replace("^(开水|冷水|温水)[- ]*", with: "", in: text)
        text = replace("^(平衡|直饮水?机?)[- ]*", with: "", in: text)
        // 3. 洗手台前缀
        text = replace("^洗手台\\d*[- ]*", with: "", in: text)
        // 4. 尾部的水类型与楼层
        text = replace("[- ](直饮)?(开水|冷水|热水|温水)$", with: "", in: text)
        text = replace("-\\d+层-", with: "-", in: text)
        text = replace("洗手台$", with: "房", in: text)
        // 5. 最后把连字符换空格
        text = text.replacingOccurrences(of: "-", with: " ")
        text = text.trimmingCharacters(in: .whitespaces)

        return text.isEmpty ? name : text
    }

    private static func replace(_ pattern: String, with template: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
