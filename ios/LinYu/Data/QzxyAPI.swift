import Foundation
import LinYuCore

/// 主链路用到的接口。签名与参数一栏都得照抄安卓，别凭感觉改。
extension APIClient {

    /// 发送短信验证码。
    ///
    /// `secret` 由手机号本地推导（见 `SmsSecret`），所以任何手机号都能用。
    /// 这个接口**不能**带认证参数——本身就是用来换认证凭证的。
    func sendVerificationCode(telephone: String, secret: String) async throws {
        try await getVoid(
            "/user/verification/code/get",
            params: [
                "telephone": telephone,
                "typeId": "3",
                "platform": "1",
                "secret": secret
            ],
            includeAuth: false
        )
    }

    /// 短信验证码登录（未注册的手机会自动注册）。
    func login(telephone: String, smsCode: String) async throws -> LoginResult {
        try await post(
            "/user/registerAndLogin",
            params: [
                "telephone": telephone,
                "smsCode": smsCode,
                "type": "5",
                "phoneSystem": "android",
                "version": APIConstants.clientVersion
            ],
            includeAuth: false
        )
    }

    /// 按 MAC 从台账查设备详情。
    ///
    /// 服务端拿 MAC 当**字符串**查，而二维码给的 12 位设备码与台账里存的可能差
    /// 首字节最高两位，所以按候选顺序逐个试——原样第一、换算值第二。
    /// 候选人顺序不能倒：多数学校第一次就命中，倒了会让每次扫码都多一次请求。
    func deviceInfo(code: String) async throws -> DeviceInfo {
        for candidate in MacFormat.lookupVariants(for: code) {
            let info: DeviceInfo? = try await getOptional(
                "/device/info/mac",
                params: ["macAddress": candidate]
            )
            if let info { return info }
        }
        throw ServerError(code: 4004, message: "没查到这台设备，可能不是本校区的设备")
    }

    // MARK: - 开阀 / 关阀 / 结算

    /// 下发费率 = 云端通道下物理开阀。
    ///
    /// - Important: 这个调用成功**不代表阀开了**，必须由 `downRateResult` 确认。
    func downRate(snCode: String) async throws {
        try await postVoid(
            "/order/tcpDevice/downRate/rateOrder",
            params: ["xfModel": "0", "snCode": snCode]
        )
    }

    /// 开阀结果确认：`data` 里带 `orderNo` 才是真开好了。
    /// 返回 nil 表示"还在处理"，要继续轮询。
    func downRateResult(snCode: String) async throws -> RateOrderResult? {
        try await postOptional(
            "/order/tcpDevice/query/downRateResult",
            params: ["snCode": snCode]
        )
    }

    /// 查询进行中的订单。这是判断"设备到底停没停"的唯一可靠信号。
    func queryUsing(snCode: String) async throws -> UsingResult? {
        try await postOptional(
            "/order/tcpDevice/query/rateOrder/using",
            params: ["xfModel": "0", "snCode": snCode]
        )
    }

    /// 关阀。`307` / 「已在关闭中」按成功处理。
    func closeOrder(snCode: String, orderNo: String) async throws {
        do {
            try await postVoid(
                "/order/tcpDevice/closeOrder",
                params: ["snCode": snCode, "orderNo": orderNo]
            )
        } catch let error as ServerError {
            if error.isOrderInProgress || error.message.contains("已在") { return }
            throw error
        }
    }

    /// 关阀结果确认。
    ///
    /// - Warning: 这个接口的 `data` **恒为 null**，只能看 HTTP 与 `errorCode`，
    ///   而且拿它当"设备已关"的证据等于没确认——真正的信号是 `queryUsing`。
    func closeOrderResult(snCode: String, orderNo: String) async throws {
        try await postVoid(
            "/order/tcpDevice/closeOrder/result/query",
            params: ["snCode": snCode, "orderNo": orderNo]
        )
    }

    /// 结算结果：`consumeMoney` 单位是**厘**。
    func consumeResult(snCode: String, orderNo: String) async throws -> ConsumeResult? {
        try await postOptional(
            "/order/consumeOrder/result/query",
            params: ["snCode": snCode, "orderNo": orderNo]
        )
    }
}
