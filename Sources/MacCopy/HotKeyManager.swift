import Cocoa
import Carbon

@MainActor
class HotKeyManager {
    static let shared = HotKeyManager()
    var action: (() -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Fallback variables for Carbon
    private var currentHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private var lastActionTime: Date = .distantPast
    
    func triggerAction() {
        let now = Date()
        if now.timeIntervalSince(lastActionTime) > 0.3 {
            lastActionTime = now
            DispatchQueue.main.async {
                self.action?()
            }
        }
    }
    
    func reloadHotKey() {
        // Clear existing tap
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        // Clear existing Carbon hotkey
        if let ref = currentHotKeyRef {
            UnregisterEventHotKey(ref)
            currentHotKeyRef = nil
        }
        
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let ref = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .tapDisabledByTimeout {
                    if let tap = ref.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }
                
                if type == .keyDown {
                    let key = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
                    
                    let expectedCode = Int64(SettingsManager.shared.hotkeyCode)
                    let expectedFlags = ref.carbonToCGModifiers(SettingsManager.shared.hotkeyModifiers)
                    
                    if key == expectedCode && flags == expectedFlags {
                        ref.triggerAction()
                        return nil // Swallow the event
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = tap {
            self.eventTap = tap
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Successfully registered CGEventTap hotkey.")
        } else {
            print("CGEventTap failed (likely missing Accessibility).")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "快捷键引擎降级警告 (Accessibility Revoked)"
                alert.informativeText = "由于软件版本更新，macOS 在底层撤销了 MacCopy 的辅助功能权限（即使系统设置里仍然显示打勾）。这导致底层快捷键拦截引擎（CGEventTap）启动失败，已降级为旧版引擎，因此 Option 组合键在部分输入框依然会失效。\n\n请前往「系统设置 -> 隐私与安全性 -> 辅助功能」，选中 MacCopy 点击「-」号删除，然后重新添加并打勾，最后重启 MacCopy 即可彻底解决此问题。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "我知道了")
                alert.runModal()
            }
        }
        
        // ALWAYS register Carbon fallback
        // This solves the Secure Input Mode issue (like password fields) where CGEventTap is forcefully blinded by macOS.
        registerCarbonFallback()
    }
    
    private func registerCarbonFallback() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("McCp".utf8.reduce(0) { $0 << 8 + UInt32($1) })
        hotKeyID.id = 1
        
        let modifiers = SettingsManager.shared.hotkeyModifiers
        let keyCode = SettingsManager.shared.hotkeyCode
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &currentHotKeyRef)
        
        if eventHandler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
                HotKeyManager.shared.triggerAction()
                return noErr
            }
            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        }
    }
    
    nonisolated private func carbonToCGModifiers(_ carbon: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        if (carbon & UInt32(cmdKey)) != 0 { flags.insert(.maskCommand) }
        if (carbon & UInt32(optionKey)) != 0 { flags.insert(.maskAlternate) }
        if (carbon & UInt32(shiftKey)) != 0 { flags.insert(.maskShift) }
        if (carbon & UInt32(controlKey)) != 0 { flags.insert(.maskControl) }
        return flags
    }
}
