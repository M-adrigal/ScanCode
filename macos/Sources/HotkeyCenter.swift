import Foundation
import Carbon.HIToolbox

final class HotkeyCenter {
    var onHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x53434F44), id: 1) // 'SCOD'

    @discardableResult
    func register() -> OSStatus {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { center.onHotkey?() }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard installStatus == noErr else { return installStatus }

        return RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    deinit { unregister() }
}
