import Foundation
import LinYuCore

/// 趣智校园 HTTP 客户端的底座。
///
/// 只做三件事：拼参数（含认证字段与 `Config-*` 头）、发请求、把响应拆成
/// `APIEnvelope` 或 `ServerError`。业务语义一律留给上层，避免这个类长成
/// 安卓 `MainViewModel` 那样 2000 行的巨物。
final class APIClient {

    private let session: URLSession

    /// 登录状态。`nil` 表示未登录，此时不会附加任何认证参数。
    var auth: AuthContext?

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    // MARK: - 公开的请求方法

    func get<Payload: Decodable>(
        _ path: String,
        params: [String: String] = [:],
        includeAuth: Bool = true
    ) async throws -> Payload {
        let envelope: APIEnvelope<Payload> = try await send(
            path: path, method: "GET", params: params, includeAuth: includeAuth
        )
        guard let payload = envelope.data else {
            throw ServerError(code: envelope.errorCode ?? -1, message: envelope.errorMessage ?? "服务端未返回数据")
        }
        return payload
    }

    func post<Payload: Decodable>(
        _ path: String,
        params: [String: String] = [:],
        includeAuth: Bool = true
    ) async throws -> Payload {
        let envelope: APIEnvelope<Payload> = try await send(
            path: path, method: "POST", params: params, includeAuth: includeAuth
        )
        guard let payload = envelope.data else {
            throw ServerError(code: envelope.errorCode ?? -1, message: envelope.errorMessage ?? "服务端未返回数据")
        }
        return payload
    }

    func getVoid(
        _ path: String,
        params: [String: String] = [:],
        includeAuth: Bool = true
    ) async throws {
        let envelope: APIEnvelope<EmptyBody> = try await send(
            path: path, method: "GET", params: params, includeAuth: includeAuth
        )
        try Self.requireSuccess(envelope)
    }

    func postVoid(
        _ path: String,
        params: [String: String] = [:],
        includeAuth: Bool = true
    ) async throws {
        let envelope: APIEnvelope<EmptyBody> = try await send(
            path: path, method: "POST", params: params, includeAuth: includeAuth
        )
        try Self.requireSuccess(envelope)
    }

    // MARK: - 内部

    private func send<Payload: Decodable>(
        path: String,
        method: String,
        params: [String: String],
        includeAuth: Bool
    ) async throws -> APIEnvelope<Payload> {
        let request = try makeRequest(path: path, method: method, params: params, includeAuth: includeAuth)
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let urlError as URLError {
            throw ServerError(code: -1, message: Self.describe(urlError))
        }
        let data = result.0
        let response = result.1

        guard let http = response as? HTTPURLResponse else {
            throw ServerError(code: -1, message: "网络异常：没有收到响应")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ServerError(code: http.statusCode, message: "登录已失效，请重新登录")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ServerError(code: http.statusCode, message: "服务端返回 HTTP \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(APIEnvelope<Payload>.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ServerError(code: -2, message: "响应解析失败：\(body.prefix(200))")
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        params: [String: String],
        includeAuth: Bool
    ) throws -> URLRequest {
        guard let baseURL = URL(string: APIConstants.baseURLString),
              let url = URL(string: path, relativeTo: baseURL) else {
            throw ServerError(code: -3, message: "接口地址无效：\(path)")
        }

        var fields = params
        var headers: [String: String] = [:]

        if includeAuth, let auth = self.auth {
            // 业务参数优先，认证参数只补空缺，避免互相覆盖。
            for (key, value) in auth.authFields where fields[key] == nil {
                fields[key] = value
            }
            if auth.hasProjectContext {
                headers["Config-Project"] = auth.projectId
                headers["Config-Keys"] = AuthContext.configKeys
            }
        }

        var request: URLRequest
        if method == "GET" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = Self.formEncode(fields)
            guard let finalURL = components?.url else {
                throw ServerError(code: -3, message: "接口地址无效：\(path)")
            }
            request = URLRequest(url: finalURL)
        } else {
            request = URLRequest(url: url)
            request.httpBody = Data(Self.formEncode(fields).utf8)
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        }

        request.httpMethod = method
        request.timeoutInterval = 20
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private static func requireSuccess(_ envelope: APIEnvelope<EmptyBody>) throws {
        if envelope.success == true { return }
        throw ServerError(code: envelope.errorCode ?? -1, message: envelope.errorMessage ?? "请求失败")
    }

    private static let unreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._*"
    )

    /// `application/x-www-form-urlencoded` 编码。
    ///
    /// 用自己写的字符集而不是 `.urlQueryAllowed`：后者会把 `&`、`=`、`+`
    /// 原样放行，手机号或中文设备名一带就散架。
    static func formEncode(_ fields: [String: String]) -> String {
        fields.keys.sorted().map { key in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? key
            let rawValue = fields[key] ?? ""
            let encodedValue = rawValue.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "网络未连接"
        case .timedOut:
            return "请求超时，请重试"
        case .cannotFindHost, .cannotConnectToHost:
            return "连不上服务器，请检查网络"
        default:
            return "网络异常：\(error.localizedDescription)"
        }
    }
}
