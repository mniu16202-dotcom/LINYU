import Foundation

/// 服务端统一响应外壳：`{ success, errorCode, errorMessage, data }`。
///
/// 字段缺失很常见（尤其 `errorMessage`），所以一律按可选、宽容解码——
/// 宁可让上层判断 `success`，也不要因为少一个字段整条响应解析失败。
struct APIEnvelope<Payload: Decodable>: Decodable {
    let success: Bool?
    let errorCode: Int?
    let errorMessage: String?
    let data: Payload?

    private enum CodingKeys: String, CodingKey {
        case success
        case errorCode
        case errorMessage
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? nil
        errorCode = (try? container.decodeIfPresent(Int.self, forKey: .errorCode)) ?? nil
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? nil
        data = (try? container.decodeIfPresent(Payload.self, forKey: .data)) ?? nil
    }
}

/// 无返回体的接口用这个占位。
struct EmptyBody: Decodable {}

/// 既可能是数字也可能是字符串的字段。
///
/// 服务端有时把 `userId` 给成 `12345678`，有时给成 `"12345678"`，
/// 甚至可能给浮点。硬编码成 `Int64` 会在某台学校的环境上直接解析失败。
struct LossyString: Decodable, Equatable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        if let integer = try? container.decode(Int64.self) {
            value = String(integer)
            return
        }
        if let double = try? container.decode(Double.self) {
            value = String(Int64(double))
            return
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "既不是字符串也不是数字"
            )
        )
    }
}

/// 既可能是数字也可能是字符串的浮点字段（例如 `withholdMoney`）。
struct LossyDouble: Decodable, Equatable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
            return
        }
        if let integer = try? container.decode(Int64.self) {
            value = Double(integer)
            return
        }
        if let string = try? container.decode(String.self), let double = Double(string) {
            value = double
            return
        }
        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "既不是数字也不是可解析的字符串"
            )
        )
    }
}

/// `/user/registerAndLogin` 的响应。
struct LoginResult: Decodable {
    let loginCode: String
    let userId: LossyString?
    let telephone: String?
    let hasPassword: Bool?
    let userAccount: AccountInfo?

    struct AccountInfo: Decodable {
        let projectId: LossyString?
        let accountId: LossyString?
        let name: String?
    }
}
