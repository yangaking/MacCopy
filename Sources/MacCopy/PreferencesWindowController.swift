import AppKit
import Carbon

class ShortcutRecordingView: NSView {
    var onShortcutRecorded: ((UInt32, UInt32, String) -> Void)?
    var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        if isRecording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
            path.stroke()
            NSColor.controlAccentColor.withAlphaComponent(0.1).setFill()
            path.fill()
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }
    
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        let carbonFlags = event.modifierFlags.carbonFlags
        let keyCode = UInt32(event.keyCode)
        
        if carbonFlags > 0 {
            let keyString = event.charactersIgnoringModifiers?.uppercased() ?? ""
            var str = ""
            if (carbonFlags & UInt32(controlKey)) != 0 { str += "⌃" }
            if (carbonFlags & UInt32(optionKey)) != 0 { str += "⌥" }
            if (carbonFlags & UInt32(shiftKey)) != 0 { str += "⇧" }
            if (carbonFlags & UInt32(cmdKey)) != 0 { str += "⌘" }
            
            let specialKeys: [UInt32: String] = [
                36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋",
                123: "←", 124: "→", 125: "↓", 126: "↑"
            ]
            if let special = specialKeys[keyCode] {
                str += special
            } else {
                str += keyString
            }
            
            onShortcutRecorded?(keyCode, carbonFlags, str)
            isRecording = false
            window?.makeFirstResponder(nil)
        }
    }
}

@MainActor
class PreferencesWindowController: NSWindowController {
    
    private let limitTextField = NSTextField()
    private let recordingView = ShortcutRecordingView()
    private let shortcutLabelDisplay = NSTextField()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setupUI() {
        guard let view = window?.contentView else { return }
        
        let limitLabel = NSTextField(labelWithString: "History Limit:")
        limitLabel.frame = NSRect(x: 20, y: 95, width: 100, height: 20)
        limitLabel.isEditable = false
        limitLabel.isBordered = false
        limitLabel.backgroundColor = .clear
        view.addSubview(limitLabel)
        
        limitTextField.frame = NSRect(x: 130, y: 95, width: 100, height: 20)
        limitTextField.stringValue = "\(SettingsManager.shared.historyLimit)"
        limitTextField.target = self
        limitTextField.action = #selector(limitChanged)
        view.addSubview(limitTextField)
        
        let shortcutLabel = NSTextField(labelWithString: "Global Shortcut:")
        shortcutLabel.frame = NSRect(x: 20, y: 55, width: 100, height: 20)
        shortcutLabel.isEditable = false
        shortcutLabel.isBordered = false
        shortcutLabel.backgroundColor = .clear
        view.addSubview(shortcutLabel)
        
        recordingView.frame = NSRect(x: 130, y: 50, width: 200, height: 30)
        
        shortcutLabelDisplay.frame = NSRect(x: 0, y: 5, width: 200, height: 20)
        shortcutLabelDisplay.isEditable = false
        shortcutLabelDisplay.isBordered = false
        shortcutLabelDisplay.backgroundColor = .clear
        shortcutLabelDisplay.alignment = .center
        shortcutLabelDisplay.stringValue = SettingsManager.shared.hotkeyString
        recordingView.addSubview(shortcutLabelDisplay)
        
        recordingView.onShortcutRecorded = { [weak self] keyCode, flags, keyStr in
            SettingsManager.shared.hotkeyModifiers = flags
            SettingsManager.shared.hotkeyCode = keyCode
            SettingsManager.shared.hotkeyString = keyStr
            HotKeyManager.shared.reloadHotKey()
            self?.shortcutLabelDisplay.stringValue = keyStr
        }
        
        view.addSubview(recordingView)
    }
    
    @objc private func limitChanged() {
        if let val = Int(limitTextField.stringValue), val > 0 {
            SettingsManager.shared.historyLimit = val
        } else {
            limitTextField.stringValue = "\(SettingsManager.shared.historyLimit)"
        }
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
