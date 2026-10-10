import AppKit

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ClipboardMonitorDelegate {
    var statusItem: NSStatusItem!
    var db: DatabaseManager!
    var clipboardMonitor: ClipboardMonitor!
    var searchWindowController: SearchWindowController!
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "MacCopy requires Accessibility permissions to automatically paste clipboard items. Please grant permission in System Settings -> Privacy & Security -> Accessibility, then restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        db = DatabaseManager()
        
        searchWindowController = SearchWindowController(db: db)
        
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor.delegate = self
        clipboardMonitor.start()
        
        HotKeyManager.shared.action = { [weak self] in
            self?.togglePopover(nil)
        }
        HotKeyManager.shared.reloadHotKey()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MacCopy")
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
        }
    }
    
    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    func showRightClickMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    var preferencesWindowController: PreferencesWindowController?
    
    @objc func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if searchWindowController.window?.isVisible == true {
            searchWindowController.hideWindow()
        } else {
            // Adjust position so it appears near the mouse but not off-screen
            var location = NSEvent.mouseLocation
            location.y -= 20
            searchWindowController.showWindow(at: location)
        }
    }
    
    func clipboardDidChange(newItem: NSPasteboardItem) {
        if let fileURLString = newItem.string(forType: .fileURL), let url = URL(string: fileURLString) {
            db.insert(content: url.path, type: "File")
            db.cleanOldRecords(limit: SettingsManager.shared.historyLimit)
            return
        }
        
        if let pngData = newItem.data(forType: .png) {
            saveImageAndInsert(data: pngData, ext: "png")
            return
        }
        
        if let tiffData = newItem.data(forType: .tiff) {
            saveImageAndInsert(data: tiffData, ext: "tiff")
            return
        }
        
        if let stringContent = newItem.string(forType: .string) {
            let trimmed = stringContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                db.insert(content: trimmed, type: "String")
                db.cleanOldRecords(limit: SettingsManager.shared.historyLimit)
            }
        }
    }
    
    private func saveImageAndInsert(data: Data, ext: String) {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("com.aking.MacCopy")
        
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let imagePath = appDir.appendingPathComponent(UUID().uuidString + "." + ext).path
        if fileManager.createFile(atPath: imagePath, contents: data, attributes: nil) {
            db.insert(content: imagePath, type: "Image")
            db.cleanOldRecords(limit: SettingsManager.shared.historyLimit)
        }
    }
}
