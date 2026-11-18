import Foundation

// MARK: - 设备 JSON

/// 固件字段随版本增删，这里用宽松字典包装，避免 Codable 在字段变化时整体失败。
struct Payload {
    let raw: [String: Any]

    init(_ raw: [String: Any]) {
        self.raw = raw
    }

    init(data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        guard let dict = object as? [String: Any] else {
            throw APIError.decoding("响应不是 JSON 对象")
        }
        self.raw = dict
    }

    static let empty = Payload([:])

    var isEmpty: Bool { raw.isEmpty }

    func obj(_ key: String) -> Payload {
        Payload(raw[key] as? [String: Any] ?? [:])
    }

    func str(_ key: String) -> String? {
        if let value = raw[key] as? String { return value }
        if let value = raw[key] as? NSNumber { return value.stringValue }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let value = raw[key] as? NSNumber { return value.intValue }
        if let value = raw[key] as? String { return Int(value) }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let value = raw[key] as? NSNumber { return value.doubleValue }
        if let value = raw[key] as? String { return Double(value) }
        return nil
    }

    func bool(_ key: String) -> Bool? {
        if let value = raw[key] as? NSNumber { return value.boolValue }
        if let value = raw[key] as? String { return value == "1" || value.lowercased() == "true" }
        return nil
    }

    /// 只用于展示原始 JSON 的调试用途。
    func compactJSON() -> String {
        guard JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "—"
        }
        return text
    }
}

// MARK: - 错误

enum APIError: LocalizedError {
    case transport(String)
    case http(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .transport(let message):
            return message
        case .http(let status, let message):
            return message.isEmpty ? "HTTP \(status)" : message
        case .decoding(let message):
            return message
        }
    }
}

// MARK: - 客户端

/// 与固件 web_api.h 通信：全部同步短请求，GET 走 query，POST 走 x-www-form-urlencoded。
final class APIClient {
    static let shared = APIClient()

    private static let storageKey = "p4can.baseURL"
    private let defaults = UserDefaults.standard
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 300
        session = URLSession(configuration: configuration)
    }

    // MARK: 地址

    var baseURLString: String {
        get { defaults.string(forKey: Self.storageKey) ?? Self.defaultBase }
        set {
            let normalized = Self.normalize(newValue)
            defaults.set(normalized.isEmpty ? Self.defaultBase : normalized, forKey: Self.storageKey)
        }
    }

    static let defaultBase = "http://192.168.4.1"

    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }
        return text
    }

    private func makeURL(_ path: String, query: [String: String]) throws -> URL {
        guard var components = URLComponents(string: baseURLString + path) else {
            throw APIError.transport("设备地址无效：\(baseURLString)")
        }
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map {
                URLQueryItem(name: $0, value: query[$0])
            }
        }
        guard let url = components.url else {
            throw APIError.transport("无法构造请求地址")
        }
        return url
    }

    private func makeRequest(path: String, query: [String: String], method: String,
                             form: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: try makeURL(path, query: query))
        request.httpMethod = method
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncoded(form)
        }
        return request
    }

    static func formEncoded(_ form: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let pairs = form.keys.sorted().map { key -> String in
            let name = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let value = (form[key] ?? "").addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(name)=\(value)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    // MARK: 请求

    func get(_ path: String, query: [String: String] = [:]) async throws -> Payload {
        let request = try makeRequest(path: path, query: query, method: "GET", form: [:])
        return try await perform(request)
    }

    func post(_ path: String, form: [String: String] = [:]) async throws -> Payload {
        let request = try makeRequest(path: path, query: [:], method: "POST", form: form)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Payload {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(Self.describe(error))
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let payload = (try? Payload(data: data)) ?? .empty

        guard (200..<300).contains(status) else {
            let message = payload.str("error") ?? payload.str("raw") ?? ""
            throw APIError.http(status: status, message: message)
        }
        return payload
    }

    static func describe(_ error: URLError) -> String {
        switch error.code {
        case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
            return "无法连接设备：请确认手机已连上热点 P4-CAN-XXXX，并在「设置」里核对地址"
        case .timedOut:
            return "请求超时：设备可能正忙或未响应"
        case .notConnectedToInternet:
            return "手机网络不可用：连接设备热点后 iOS 可能提示「无互联网连接」，选择保持连接即可"
        case .appTransportSecurityRequiresSecureConnection:
            return "HTTP 被 ATS 拦截：请确认 Info.plist 中允许本地明文访问"
        default:
            return error.localizedDescription
        }
    }

    // MARK: OTA 上传

    /// 固件在 /update 中由 server.upload() 接管，表单字段名不影响结果。
    func uploadFirmware(fileName: String, data: Data) async throws -> Payload {
        var request = try makeRequest(path: "/update", query: [:], method: "POST", form: [:])
        let boundary = "----P4CAN\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var body = Data()
        func append(_ text: String) { body.append(contentsOf: Array(text.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"update\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        return try await perform(request)
    }
}
