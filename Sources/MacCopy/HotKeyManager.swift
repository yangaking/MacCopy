import Cocoa
import Carbon

@MainActor
class HotKeyManager {
    static let shared = HotKeyManager()
    var action: (() -> Void)?
    
    private var currentHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    func reloadHotKey() {
        if let ref = currentHotKeyRef {
            UnregisterEventHotKey(ref)
            currentHotKeyRef = nil
        }
        
        var hotKeyID = EventHotKeyID()
        let signatureStr = "McCp"
        hotKeyID.signature = OSType(signatureStr.utf8.reduce(0) { $0 << 8 + UInt32($1) })
        hotKeyID.id = 1
        
        let modifiers = SettingsManager.shared.hotkeyModifiers
        let keyCode = SettingsManager.shared.hotkeyCode
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &currentHotKeyRef)
        
        if eventHandler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
                Task { @MainActor in
                    HotKeyManager.shared.action?()
                }
                return noErr
            }
            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        }
    }
}
