import Foundation

enum DispatchTest {
    static func run() -> Bool {
        let payload = ContentParser.parse("https://pan.baidu.com/s/1abc?pwd=ab12")
        var ok = true
        for app in AppRegistry.all {
            let before = AppRegistry.state(app)
            if before == .running {
                print("[dispatch-test] SKIP \(app.id) is running (avoid side effects)")
                continue
            }
            do {
                let message = try Dispatcher.dispatch(payload, to: app)
                print("[dispatch-test] FAIL \(app.id) unexpectedly dispatched: \(message)")
                ok = false
            } catch let error as ToolError {
                switch error {
                case .appNotRunning, .appNotInstalled:
                    let after = AppRegistry.state(app)
                    if after == before {
                        print("[dispatch-test] PASS \(app.id) blocked (\(error.localizedDescription))")
                    } else {
                        print("[dispatch-test] FAIL \(app.id) state changed \(before.rawValue) -> \(after.rawValue)")
                        ok = false
                    }
                default:
                    print("[dispatch-test] FAIL \(app.id) unexpected error: \(error.localizedDescription)")
                    ok = false
                }
            } catch {
                print("[dispatch-test] FAIL \(app.id) \(error)")
                ok = false
            }
        }
        print(ok ? "[dispatch-test] ALL PASS (no cold launch)" : "[dispatch-test] FAILED")
        return ok
    }
}
