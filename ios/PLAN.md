# iOS 移植方案 — 淋浴 MVP（云端通道）

> 状态：已确认（2026-10-20，逐项答复）· 里程碑 M0/M1 已落地
> 术语表与调研报告在工作区（仓库外）：`CONTEXT.md`、`docs/research/*.md`
> 协议契约以本文件 §4 为准，改协议先改这里

## 1. 目标

交付一个**能装进 iPhone、走云端通道**完成主链路的最小客户端：

> 短信登录 → 扫码取设备 → 选设备 → 下发费率（开阀）→ 使用中计时 → 关阀 → 订单结算金额

必须运行在 **iOS 26.6.1** 的设备上。受众为团队内部开发者，分发方式为**免费 Apple ID 签名**（后续再切 TestFlight）。

## 2. 非目标（本次明确不做，记入 v2）

| 不做 | 原因 |
|---|---|
| BLE 直连水表 | 用户决策；且目标部署是联网表（`tcpDevice`），云端通道可达。**注意**：若真机上 `downRate` 回 306，说明目标表其实是蓝牙表，本项目立刻停并回到方案修订 |
| MQTT 实时推送 | iOS 后台不允许长连接；改用前台 HTTP 轮询 |
| 桌面小组件 | WidgetKit 扩展进程不能声明 `bluetooth-central`，且 MVP 无 BLE，组件只剩"看"与"点开 App" |
| Live Activity / 通知 | 同上，v2 再评估 |
| 应用内自更新 | 指南 2.5.2 明禁下载安装代码；改为重新签名安装包 |
| 背景装扮取色 / 使用码 / 消费趋势 / 挤号横幅 / 一卡通签约 | 均在主链路之外 |
| 密码登录 | 用户选择只做短信；`hasPassword` 字段仍会解析，留给 v2 |
| 附近设备蓝牙扫描列表 | 无 BLE 即无意义 |

## 3. 技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| UI | **SwiftUI**，deployment target **iOS 17.0** | 可在 26.6.1 上运行；17 起 `@Observable`/`ContentUnavailableView` 可用 |
| 工程生成 | **XcodeGen**（`ios/project.yml`） | 工程定义是可 review 的文本，加文件不用手改 `pbxproj` |
| 网络 | `URLSession` + `async/await`，不上第三方库 | 只有 7 个表单接口，Alamofire 是负债 |
| JSON | `Codable`，宽容解码（`errorCode`/`errorMessage` 可能缺省） | 服务端字段不稳定 |
| 安全存储 | **Keychain**（`kSecClassGenericPassword`） | 对齐安卓 `EncryptedSharedPreferences` |
| 扫码 | `AVCaptureMetadataOutput` + 手电筒 | 与 `DataScannerViewController` 比，兼容更广、可完全自绘深色 UI |
| 架构 | 三层：`Core`（纯逻辑，可单测）/ `Data`（API 与存储）/ `Features`（SwiftUI 页面） | CI 只能跑模拟器测试，纯逻辑层必须能脱离 UIKit 测 |
| 编译校验 | **GitHub Actions `macos-latest`** 跑 `xcodebuild` 模拟器构建 + `swift test` | 开发机是 Windows，必须靠 CI 拿到编译错误 |

## 4. 协议契约（照抄安卓，勿自行发挥）

`BASE_URL = https://v3-api.china-qzxy.cn`

### 4.1 全局认证参数

每个已登录请求都带（GET 拼 query、POST 拼 form）：

```
loginCode, userId, accountId, projectId,
telephone, telPhone,          ← 两个都要传，值相同
phoneSystem=android,          ← 故意伪装安卓（服务端对 ios 的行为未知）
version=6.5.28
```

外加两个请求头（对齐官方 v3 API，缺了会出 226）：

```
Config-Project: {projectId}
Config-Keys: module_list,advertise_type,question_list,service_phone_list,banner_list_app,activity_list_app,aliCard_popup_config
```

### 4.2 主链路调用

| # | 方法 | 路径 | 关键参数 |
|---|---|---|---|
| 1 | GET | `/user/verification/code/get` | `telephone`, `typeId=3`, `platform=1`, `secret` |
| 2 | POST | `/user/registerAndLogin` | `telephone`, `smsCode`, `type=5`, `phoneSystem`, `version` |
| 3 | GET | `/device/info/mac` | `macAddress`（**多候选顺序尝试**） |
| 4 | POST | `/order/tcpDevice/downRate/rateOrder` | `xfModel=0`, `snCode` |
| 5 | POST | `/order/tcpDevice/query/downRateResult` | `snCode`（轮询到确认为止） |
| 6 | POST | `/order/tcpDevice/query/rateOrder/using` | `xfModel=0`, `snCode`（使用中轮询） |
| 7 | POST | `/order/tcpDevice/closeOrder` | `snCode`, `orderNo` |
| 8 | POST | `/order/tcpDevice/closeOrder/result/query` | `snCode`, `orderNo` |
| 9 | POST | `/order/consumeOrder/result/query` | `snCode`, `orderNo` |

`secret = MD5(手机号前3位 + 手机号后4位 + "klcx")`，32 位小写。

### 4.3 判读规则（最容易写错的部分）

- **成功不是 `state == 0`**：订单成功语义是 `state == 1 && result == 0`；HTTP 200 不代表成功，必须看 `errorCode`。
- `consumeMoney`（`/order/consumeOrder/result/query`，数字）单位是**厘**，除以 1000；而账单列表里**同名**字段是字符串、单位是元。同名不同单位，算错是静默错 1000 倍。`/device/info/mac` 的 `withholdMoney` 是元。
- `consumeDate` 是 `yyyyMMddHHmmss`（下单时刻，非结算时刻）。
- 错误码语义：`306` = 设备不在线（**本项目一旦出现即为方案级问题**）、`307` = 已有订单/正在关闭、`170` = 签名错、`226` = 加密校验失败、`4004` = 缺参数/查不到。
- `downRate` 发出去后**不代表开阀成功**，必须由 `downRateResult` 确认；确认超时属"结果未知"，不能当失败处理（否则用户可能被重复计费）。
- `/order/tcpDevice/closeOrder/result/query` 的 `data` 实测恒为 `null`，只能以 HTTP + `errorCode` 判读。

### 4.4 设备查找的 MAC 候选

二维码内容形如 `KLCXKJ-Water,M,AABBCCDDEEFF`，取最后一个逗号后的 12 位十六进制作为 `snCode`/MAC。查设备时按序尝试：

1. 原样（12 位大写无分隔）
2. 首字节清掉最高两位后的小写形式（`C0:15:83:04:D3:00` → `00158304d300`）

顺序不能倒：多数学校第一个就命中，倒了会让每次扫码多一次请求。

## 5. 里程碑与验收

每个里程碑都必须**在真机上**验收，不接受"编译通过即完成"。

| 里程碑 | 内容 | 验收标准 |
|---|---|---|
| **M0 骨架** | `project.yml`、App 入口、主题、CI workflow、版本号页 | CI 绿；装进 iPhone 能启动 |
| **M1 登录** | 短信发码（60s 冷却）、登录、Keychain 持久化、自动恢复、登出 | 真机能收到码并登录；杀进程重开仍是登录态 |
| **M2 设备** | 扫码页（手电筒/相册）、MAC 候选回退、设备详情页 | 扫真表二维码能显示设备名、类型、预扣金额 |
| **M3 开阀** | `downRate` → `downRateResult` 轮询确认 → 使用中页（计时、余额） | 真机点开阀**能出水**；失败有明确原因 |
| **M4 关阀与结算** | `closeOrder` → 结果确认 → `consumeOrderResult` → 金额与时长 | 真机点关阀**水停**；显示本次金额与时长 |

M0–M4 = MVP。错误矩阵打磨、日志面板、网络异常态归入 M5，与 MVP 并行收尾。

## 6. 验收清单（人工，真机）

- [ ] 冷启动 → 登录 → 杀进程 → 重开：仍是登录态
- [ ] 扫码 → 设备详情字段与服务端一致（名称/类型/预扣）
- [ ] 开阀 → 出水 → 页面显示"使用中"且计时在走
- [ ] 使用中杀进程 → 重开 → 能恢复"使用中"（走 `queryUsing`）
- [ ] 关阀 → 水停 → 金额与时长出现，且与安卓同一单一致
- [ ] 306 / 307 / 网络断开三种情况的提示文案可读
- [ ] 连续开阀两次：第二次被 307 正确拦截，不产生第二笔订单

## 7. 风险与未知

| 风险 | 影响 | 应对 |
|---|---|---|
| **我在 Windows 上盲写 Swift** | 编译错误只能靠 CI 反馈 | M0 就把 CI 打通；小步提交，不让错误堆积 |
| **306（表其实不联网）** | MVP 直接不成立 | M3 第一件事就是真机验证开阀；一旦 306 立即停 |
| `phoneSystem=android` 伪装 | 未知的服务端分支 | 沿用安卓值；若出现异常再单独实验 |
| 免费签名 7 天过期 | 内部试用麻烦 | 每次安装前重签；账号下来后切 TestFlight |
| Xcode 26 默认新外观（Liquid Glass） | 视觉与设计稿不符 | 先接受系统默认，不额外做适配 |
| 工程代码放哪 / CI 归属 | 阻塞 CI 打通 | 已定：`ios/` 进本仓库，CI 用单独 workflow；见 §8 |

## 8. 交付物

实际落地结构（`Core` 单独做成 Swift Package，因此单测不需要模拟器）：

```
ios/
├── project.yml            # XcodeGen 工程定义
├── PLAN.md                # 本文
├── ADR/                   # 决策记录
├── README.md              # 构建与首次上手
├── LinYu/                 # App 目标
│   ├── App/               # 入口、会话、路由
│   ├── Data/              # API 客户端、Keychain、模型
│   ├── Features/          # Login / Home（M2 起加 Scan / Shower）
│   └── Resources/         # Assets
└── LinYuCore/             # 纯逻辑 Swift Package + 单测
.github/workflows/ios.yml  # macos-latest：swift test + xcodebuild（免签名）
```

**首次在云 Mac 上跑：**

```bash
brew install xcodegen
cd ios && xcodegen generate
open LinYu.xcodeproj      # 选 Personal Team、填 Bundle ID、连设备后 Run
```
