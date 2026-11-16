import Foundation

enum ContentParser {
    private static let urlRegex = try! NSRegularExpression(
        pattern: #"(?:https?://|magnet:\?)[^\s\u3000]+"#,
        options: [.caseInsensitive]
    )
    private static let codeRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:提取码|访问码|密码|pwd|password|code)\s*[:：=]\s*([A-Za-z0-9]{4,8})"#,
        options: []
    )
    private static let queryCodeRegex = try! NSRegularExpression(
        pattern: #"(?i)[?&](?:pwd|password|code)=([A-Za-z0-9]{4,8})"#,
        options: []
    )

    static func parse(_ raw: String) -> QRPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = extractURL(from: trimmed)
        let provider = classify(url: url, raw: trimmed)
        let code = extractCode(from: trimmed, url: url)
        let title: String
        switch provider {
        case .baidu: title = "百度网盘分享链接"
        case .quark: title = "夸克网盘链接"
        case .web: title = "网页链接"
        case .text: title = "文本内容"
        }

        let clipboardText: String
        if provider == .baidu {
            if let url {
                clipboardText = code.map { "\(url.absoluteString)\n提取码: \($0)" } ?? url.absoluteString
            } else {
                clipboardText = trimmed
            }
        } else if provider == .quark, let url {
            clipboardText = url.absoluteString
        } else {
            clipboardText = trimmed
        }

        return QRPayload(
            raw: trimmed,
            url: url,
            provider: provider,
            extractCode: code,
            title: title,
            clipboardText: clipboardText
        )
    }

    static func extractURL(from text: String) -> URL? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = urlRegex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range, in: text) {
            return normalizedURL(String(text[matchRange]))
        }
        // 没有 scheme 的裸域名（常见于网盘分享文本）
        let lower = text.lowercased()
        for host in ["pan.baidu.com/", "eyun.baidu.com/", "pan.quark.cn/", "drive.quark.cn/"] {
            if let r = lower.range(of: host) {
                let suffix = text[r.lowerBound...]
                let candidate = String(suffix).trimmingCharacters(in: .whitespacesAndNewlines)
                return normalizedURL("https://" + candidate)
            }
        }
        return nil
    }

    private static func normalizedURL(_ string: String) -> URL? {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailing = CharacterSet(charactersIn: "。，、；：）】》》,.;:!?！？")
        while let last = value.unicodeScalars.last, trailing.contains(last) {
            value.removeLast()
        }
        if value.hasPrefix("magnet:") {
            return URL(string: value)
        }
        return URL(string: value)
    }

    private static func classify(url: URL?, raw: String) -> Provider {
        if let url {
            let host = (url.host ?? "").lowercased()
            if host == "pan.baidu.com" || host.hasSuffix(".pan.baidu.com") ||
                host == "eyun.baidu.com" || host.hasSuffix(".eyun.baidu.com") {
                return .baidu
            }
            if host == "pan.quark.cn" || host.hasSuffix(".pan.quark.cn") ||
                host == "drive.quark.cn" || host.hasSuffix(".drive.quark.cn") {
                return .quark
            }
            if url.scheme?.lowercased() == "magnet" { return .quark }
            return .web
        }
        if raw.contains("百度网盘") { return .baidu }
        if raw.contains("夸克") { return .quark }
        return .text
    }

    private static func extractCode(from text: String, url: URL?) -> String? {
        if let url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {
            for item in items {
                let name = item.name.lowercased()
                if ["pwd", "password", "code", "passcode"].contains(name),
                   let value = item.value, !value.isEmpty {
                    return value
                }
            }
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for regex in [codeRegex, queryCodeRegex] {
            if let match = regex.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges > 1,
               let r = Range(match.range(at: 1), in: text) {
                return String(text[r])
            }
        }
        return nil
    }
}
