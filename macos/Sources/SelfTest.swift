import Foundation

enum SelfTest {
    static func run() -> Bool {
        var ok = true

        let cases: [(String, Provider, String?)] = [
            ("https://pan.baidu.com/s/1QrDemo8xK?pwd=8xk2", .baidu, "8xk2"),
            ("https://pan.quark.cn/s/1AbCdEf", .quark, nil),
            ("https://example.com/hello", .web, nil),
            ("链接: https://pan.baidu.com/s/1abc 提取码: ab12", .baidu, "ab12")
        ]

        for (text, expectedProvider, expectedCode) in cases {
            guard let image = QRCodeImage.make(text, scale: 10) else {
                print("[selftest] FAIL generate \(text)")
                ok = false
                continue
            }
            guard let decoded = QRDecoder.decode(image).first else {
                print("[selftest] FAIL decode \(text)")
                ok = false
                continue
            }
            let payload = ContentParser.parse(decoded.raw)
            let providerOK = payload.provider == expectedProvider
            let codeOK = payload.extractCode == expectedCode
            print("[selftest] \(providerOK && codeOK ? "PASS" : "FAIL") provider=\(payload.provider.rawValue) code=\(payload.extractCode ?? "-") raw=\(payload.raw)")
            if !providerOK || !codeOK { ok = false }
        }

        let textPayload = ContentParser.parse("复制这段内容后打开百度网盘，链接：https://pan.baidu.com/s/1xyz 提取码：A1B2")
        if textPayload.provider == .baidu && textPayload.extractCode == "A1B2" {
            print("[selftest] PASS text extraction")
        } else {
            print("[selftest] FAIL text extraction provider=\(textPayload.provider.rawValue) code=\(textPayload.extractCode ?? "-")")
            ok = false
        }

        print(ok ? "[selftest] ALL PASS" : "[selftest] FAILED")
        return ok
    }
}
