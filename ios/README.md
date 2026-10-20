# iOS 端（淋浴 MVP）

趣智校园第三方客户端的 iOS 移植。**当前只做云端通道（`/order/tcpDevice/*`）**：
不含 BLE、MQTT、桌面小组件、应用内更新。范围与取舍见
[PLAN.md](PLAN.md) 与 [ADR/0001](ADR/0001-swiftui-native-mvp.md)。

## 目录

```
ios/
├── project.yml            XcodeGen 工程定义（唯一真相，别手改 .xcodeproj）
├── LinYuCore/             纯逻辑 Swift Package：单元测试跑在 CI 上
│   ├── Sources/LinYuCore/ 签名、MAC 换算、金额、时间、错误码
│   └── Tests/             swift test 直接可跑，不需要模拟器
├── LinYu/                 App 目标
│   ├── App/               入口、会话、路由
│   ├── Data/              API 客户端、Keychain、模型
│   ├── Features/          Login / Home
│   └── Resources/         Assets
└── .gitignore             build/、*.xcodeproj 都是生成物
```

## 首次在 Mac 上跑

```bash
# 1. 装 XcodeGen（只需要一次）
brew install xcodegen

# 2. 生成工程
cd ios
xcodegen generate

# 3. 打开
open LinYu.xcodeproj
```

在 Xcode 里：

1. 选中 `LinYu` target → **Signing & Capabilities**
2. `Team` 选你的 **Personal Team**（免费 Apple ID 即可）
3. `Bundle Identifier` 若冲突，改成 `com.hualala.linyu.<你的名字>` —— 免费签名要求账号内唯一
4. 连上 iPhone，选中设备 → Run

> 免费签名有三个限制：**7 天过期**（到期重新 Run 一次）、**最多 3 个 App**、
> **最多 3 台设备**。这不影响 M1–M4 的开发验证；等要发给别人用时再上 TestFlight（需要付费账号）。

## 本地跑测试

```bash
cd ios/LinYuCore
swift test
```

`LinYuCore` 不依赖 UIKit，所以测试不需要模拟器，秒级完成。回归重点全在这里：
短信 secret、MAC 候选顺序、金额分转元、`yyyyMMddHHmmss` 解析、错误码文案。

## CI

`.github/workflows/ios.yml`，跑在 `macos-latest` 上，两个 job：

- **Core 单测**：`swift test --parallel`
- **编译**：`xcodegen generate` → `xcodebuild build`（模拟器、免签名）

所以**推送 `ios/**` 的改动会自动得到编译结果**，不需要每次都开 Mac。

## 里程碑

见 [PLAN.md](PLAN.md#5-里程碑与验收)。当前进度：

- [x] **M0** 工程骨架、CI、App 可启动
- [x] **M1** 短信登录、Keychain 持久化、自动恢复
- [ ] **M2** 扫码 + MAC 候选回退 + 设备详情
- [ ] **M3** 下发费率（开阀）+ 轮询确认 + 使用中页
- [ ] **M4** 关阀 + 结算金额与时长

## 三条别踩的坑

1. **成功不是 `state == 0`**：订单成功是 `state == 1 && result == 0`；HTTP 200 也不代表成功。
2. **金额单位是"厘"不是"分"**：`consumeOrder/result/query` 的 `consumeMoney` 数字要 ÷1000；账单列表里同名的是字符串、单位元。安卓 `MoneyFormat.milliToYuan` 是权威参照。
3. **`downRate` 发出去 ≠ 开阀成功**，必须由 `downRateResult` 确认；确认超时是"结果未知"，不能当失败（否则可能重复计费）。

另外：`306` 表示设备不在线。云端通道上出现它，通常说明这台其实是**蓝牙表**——
那不是 bug，是方案级问题，停下来讨论。
