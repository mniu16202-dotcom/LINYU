# ADR 0001 — iOS 端用原生 SwiftUI 重写，MVP 只做云端通道

- 状态：已接受（2026-10-20）
- 日期：2026-10-20

## 背景

「淋浴」现有实现是 Kotlin + Jetpack Compose 的 Android 客户端，约 1.1 万行、89 个文件，功能完整：短信/密码登录、扫码、蓝牙直连水表、MQTT 订单推送、前台服务常驻监控、四种桌面小组件、应用内自更新、背景装扮、使用码、消费趋势、挤号检测、账单。

现在需要 iOS 版本。目标是内部开发者在 iPhone（iOS 26.6.1）上跑通主链路，分发方式为免费签名。团队无 iOS 生产经验依赖，开发机为 Windows，编译验证只能依靠 CI 或云 Mac。

## 决策

1. **iOS 用原生 SwiftUI 重写，不与 Android 共享代码。**
2. **MVP 只做云端通道（`/order/tcpDevice/*`），不含 BLE。**
3. **MVP 不含 MQTT 推送，使用中状态靠前台 HTTP 轮询。**
4. **MVP 不含桌面小组件、Live Activity、通知、应用内自更新。**
5. **登录只做短信验证码。**
6. Bundle ID 沿用 `com.hualala.linyu`，显示名「淋浴」，deployment target iOS 17.0。

## 备选方案与放弃理由

| 备选 | 放弃原因 |
|---|---|
| **KMP 共享 core**（把签名、MAC 换算、结算状态机抽成 Kotlin） | 去掉 BLE/MQTT/小组件后，值得共享的逻辑剩下几百行；而引入 KMP 会立刻带来 Gradle 与 Xcode 双构建链、cinterop 调试、CI 复杂度。等两端都在跑、确实需要同步维护时再抽，成本更低且目标明确 |
| **Compose Multiplatform 共享 UI** | 需要把 Android 改造成 KMP 工程结构（2065 行 `MainViewModel`、Compose 依赖全部 KMP 化），等于把"已经跑通、有真实用户在用水"的安卓端拖进重构风险。收益是长期只写一份 UI，但 iOS 侧的 BLE 后台、WidgetKit、Live Activity、APNs 这些"最值钱的能力"在 CMP 里仍然要写 Swift |
| **Flutter 重写双端** | 推翻已跑通的安卓端；且 Flutter 在 iOS 的 BLE 后台、WidgetKit、APNs 同样要写原生插件 |
| **iOS 套 WebView / H5** | 安卓端没有任何 H5 页面（全 Compose），不存在可复用的 Web 资产 |

## 后果

**正面**
- 单链路的 7 个表单接口 + 扫码页，规模从"移植一个 App"降到"重写一个薄客户端"，可在一到两周内真机跑通。
- 无第三方依赖，XcodeGen + CI 即可完成大部分验证。
- iOS 端从一开始就没有历史包袱（无 R8、无 `MainViewModel` 巨类、无 SharedPreferences 明文回退）。

**负面 / 需要记住的债**
- 两端协议实现**各写一份**，`KlcxkjSigner` 那套嵌套 MD5 签名、MAC 候选顺序、`state==1 && result==0` 判读规则一旦服务端变化，必须同时改两处。缓解：把协议契约固化在 `docs/ios-port-plan.md` §4，并在 iOS 侧补上安卓至今缺失的 golden test（`BleFrame` 无测试是既有隐患）。
- 功能上与安卓**长期不对等**：没有小组件、没有后台监控、没有 BLE。这不是"以后补补就有"，其中小组件与后台监控在 iOS 上需要产品叙事降级 + 服务端 APNs 支持才能补。
- 免费签名的 7 天期限会成为内部试用的固定摩擦点，直到 TestFlight 账号到位。

## 触发重新评估的条件

- 目标的表其实是蓝牙表（`downRate` 回 306）→ BLE 必须进入 MVP，本 ADR 的第 2 条作废。
- 团队决定长期单人维护双端 → KMP 共享 core 的收益超过其成本，应提前到 MVP 阶段。
- 只剩 iOS 端继续演进（安卓冻结）→ 无需再考虑共享，本决策自然失效。
