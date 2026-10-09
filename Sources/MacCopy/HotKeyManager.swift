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
        
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.tapDisabledByTimeout.rawValue)
        
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
                        DispatchQueue.main.async {
                            ref.action?()
                        }
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
            print("CGEventTap failed (likely missing Accessibility). Falling back to Carbon RegisterEventHotKey.")
            registerCarbonFallback()
        }
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
                Task { @MainActor in
                    HotKeyManager.shared.action?()
                }
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
