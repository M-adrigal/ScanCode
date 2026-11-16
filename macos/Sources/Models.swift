import Foundation
import AppKit

enum Provider: String {
    case baidu
    case quark
    case web
    case text

    var displayName: String {
        switch self {
        case .baidu: return "百度网盘"
        case .quark: return "夸克"
        case .web: return "网页"
        case .text: return "文本"
        }
    }
}

struct QRPayload {
    let raw: String
    let url: URL?
    let provider: Provider
    let extractCode: String?
    let title: String
    let clipboardText: String

    var host: String { url?.host?.lowercased() ?? "" }
    var hasNetdiskTarget: Bool { provider == .baidu || provider == .quark }

    var summary: String {
        guard let url else {
            return raw.replacingOccurrences(of: "\n", with: " ")
        }
        var text = url.host ?? ""
        if !url.path.isEmpty { text += url.path }
        if let query = url.query, !query.isEmpty { text += "?" + query }
        return text
    }
}

struct DecodedQR {
    let raw: String
    let bounds: CGRect
}

struct QRHotspot {
    let rect: NSRect
    let payload: QRPayload
}

struct CapturedDisplay {
    let screen: NSScreen
    let image: CGImage
}

enum AppState: String {
    case running
    case notRunning
    case notInstalled
}

struct AppDescriptor: Identifiable {
    let id: String
    let name: String
    let bundleID: String
    let installURL: URL
    let provider: Provider
}

enum ToolError: LocalizedError {
    case appNotInstalled(String)
    case appNotRunning(String)
    case dispatchFailed(String)
    case noQR
    case noURL
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let name): return "本地暂无可使用的\(name)"
        case .appNotRunning(let name): return "\(name)未启动"
        case .dispatchFailed(let msg): return msg
        case .noQR: return "没有识别到二维码"
        case .noURL: return "这个二维码没有可打开的链接"
        case .captureFailed(let msg): return "无法截取屏幕：\(msg)"
        }
    }
}
