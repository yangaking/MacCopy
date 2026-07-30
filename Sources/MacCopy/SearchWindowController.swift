import AppKit
import CoreGraphics

class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class CustomTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 0), xRadius: 5, yRadius: 5)
        path.fill()
    }
}

class CustomTableCellView: NSTableCellView {
    var customImageView: NSImageView!
    var customTextField: NSTextField!
    var shortcutLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        customImageView = NSImageView(frame: .zero)
        customImageView.imageScaling = .scaleProportionallyUpOrDown
        customImageView.imageAlignment = .alignLeft
        addSubview(customImageView)
        
        customTextField = NSTextField(frame: .zero)
        customTextField.isEditable = false
        customTextField.isBordered = false
        customTextField.backgroundColor = .clear
        customTextField.lineBreakMode = .byTruncatingTail
        customTextField.maximumNumberOfLines = 1
        customTextField.alignment = .left
        addSubview(customTextField)
        
        shortcutLabel = NSTextField(frame: .zero)
        shortcutLabel.isEditable = false
        shortcutLabel.isBordered = false
        shortcutLabel.backgroundColor = .clear
        shortcutLabel.alignment = .right
        shortcutLabel.textColor = NSColor.secondaryLabelColor
        addSubview(shortcutLabel)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        
        // Match Maccy's exact layout:
        // Left margin 8px
        // Right margin 8px
        // Shortcut label takes 30px on the right
        
        shortcutLabel.frame = NSRect(x: bounds.width - 38, y: 5, width: 30, height: 20)
        
        if customImageView.image != nil && customTextField.stringValue.isEmpty {
            // Image ONLY mode (like Maccy)
            customImageView.frame = NSRect(x: 8, y: 5, width: bounds.width - 16 - 40, height: bounds.height - 10)
            customTextField.frame = .zero
        } else if customImageView.image != nil {
            // Icon + Text (for Files)
            customImageView.frame = NSRect(x: 8, y: 5, width: 20, height: 20)
            customTextField.frame = NSRect(x: 36, y: 5, width: bounds.width - 36 - 40, height: 20)
        } else {
            // Text ONLY mode
            customImageView.frame = .zero
            customTextField.frame = NSRect(x: 8, y: 5, width: bounds.width - 8 - 40, height: 20)
        }
    }
    
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            let color = (backgroundStyle == .emphasized) ? NSColor.white : NSColor.textColor
            customTextField.textColor = color
            shortcutLabel.textColor = (backgroundStyle == .emphasized) ? NSColor.white.withAlphaComponent(0.8) : NSColor.secondaryLabelColor
        }
    }
}

class SearchWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    
    private var db: DatabaseManager
    private var allItems: [(id: Int, content: String, type: String)] = []
    private var filteredItems: [(id: Int, content: String, type: String)] = []
    
    private var eventMonitor: Any?
    private var globalEventMonitor: Any?
    private var hoverEventMonitor: Any?
    
    private var previewWindowController = PreviewWindowController()
    private var previewTask: Task<Void, Never>?
    private var lastHoveredRow: Int = -1
    
    init(db: DatabaseManager) {
        self.db = db
        let window = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.acceptsMouseMovedEvents = true
        
        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(appDidResignActive), name: NSApplication.didResignActiveNotification, object: nil)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let visualEffect = NSVisualEffectView(frame: window.contentRect(forFrameRect: window.frame))
        visualEffect.material = .menu
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.autoresizingMask = [.width, .height]
        window.contentView = visualEffect
        
        // Search Field exactly at top
        searchField.frame = NSRect(x: 10, y: 415, width: 330, height: 22)
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.target = self
        searchField.action = #selector(searchTextChanged(_:))
        searchField.delegate = self
        searchField.isBordered = true
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.placeholderString = "搜索..."
        visualEffect.addSubview(searchField)
        
        let separator = NSBox(frame: NSRect(x: 0, y: 400, width: 350, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        visualEffect.addSubview(separator)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ContentColumn"))
        column.width = 330
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.style = .plain
        
        scrollView.frame = NSRect(x: 0, y: 10, width: 350, height: 390)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        visualEffect.addSubview(scrollView)
    }
    
    func showWindow(at point: NSPoint? = nil) {
        reloadData()
        searchField.stringValue = ""
        filteredItems = allItems
        tableView.reloadData()
        
        if let window = window {
            if let point = point {
                if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
                    var safePoint = point
                    safePoint.y -= 10
                    if safePoint.x + window.frame.width > screen.visibleFrame.maxX {
                        safePoint.x = screen.visibleFrame.maxX - window.frame.width - 10
                    }
                    if safePoint.y - window.frame.height < screen.visibleFrame.minY {
                        safePoint.y = screen.visibleFrame.minY + window.frame.height + 10
                    }
                    window.setFrameTopLeftPoint(safePoint)
                } else {
                    window.setFrameTopLeftPoint(point)
                }
            } else {
                window.center()
            }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(searchField)
            
            if globalEventMonitor == nil {
                globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    self?.hideWindow()
                }
            }
            
            if hoverEventMonitor == nil {
                hoverEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                    self?.handleMouseMoved(event)
                    return event
                }
            }
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if modifiers == .command {
                    if let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1 && num <= 9 {
                        let index = num - 1
                        if index < self.filteredItems.count {
                            self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                            self.pasteAndHide(row: index)
                            return nil
                        }
                    }
                }
                return event
            }
        }
    }
    
    func hideWindow() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = hoverEventMonitor {
            NSEvent.removeMonitor(monitor)
            hoverEventMonitor = nil
        }
        
        previewTask?.cancel()
        previewWindowController.hidePreview()
        lastHoveredRow = -1
        
        window?.orderOut(nil)
        allItems.removeAll(keepingCapacity: true)
        filteredItems.removeAll(keepingCapacity: true)
        tableView.reloadData()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        hideWindow()
    }
    
    @objc private func appDidResignActive() {
        hideWindow()
    }
    
    private func reloadData() {
        allItems = db.fetchRecent(limit: SettingsManager.shared.historyLimit)
    }
    
    @objc private func searchTextChanged(_ sender: NSSearchField) {
        let query = sender.stringValue.lowercased()
        if query.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter { $0.content.lowercased().contains(query) }
        }
        tableView.reloadData()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let row = tableView.selectedRow
            if row > 0 {
                tableView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row - 1)
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let row = tableView.selectedRow
            if row < filteredItems.count - 1 {
                tableView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row + 1)
            } else if row == -1 && !filteredItems.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                tableView.scrollRowToVisible(0)
            }
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let row = tableView.selectedRow
            if row >= 0 && row < filteredItems.count {
                pasteAndHide(row: row)
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hideWindow()
            return true
        }
        return false
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let item = filteredItems[row]
        if item.type == "Image" {
            if let image = NSImage(contentsOfFile: item.content) {
                let ratio = image.size.width / image.size.height
                let maxWidth: CGFloat = 250
                let calculatedHeight = maxWidth / ratio
                if calculatedHeight > 80 { return 80 }
                if calculatedHeight < 30 { return 30 }
                return calculatedHeight
            }
            return 60
        }
        return 30
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("RowView")
        var view = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomTableRowView
        if view == nil {
            view = CustomTableRowView()
            view?.identifier = identifier
        }
        return view
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("Cell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomTableCellView
        
        if cell == nil {
            cell = CustomTableCellView()
            cell?.identifier = identifier
        }
        
        let item = filteredItems[row]
        if item.type == "Image" {
            cell?.customTextField?.stringValue = ""
            if let image = NSImage(contentsOfFile: item.content) {
                cell?.customImageView?.image = image
            } else {
                cell?.customImageView?.image = nil
            }
        } else if item.type == "File" {
            let url = URL(fileURLWithPath: item.content)
            cell?.customTextField?.stringValue = url.lastPathComponent
            cell?.customImageView?.image = NSWorkspace.shared.icon(forFile: item.content)
        } else {
            cell?.customImageView?.image = nil
            let displayContent = item.content.replacingOccurrences(of: "\n", with: " ")
            cell?.customTextField?.stringValue = displayContent
        }
        
        if row < 9 {
            cell?.shortcutLabel.stringValue = "⌘ \(row + 1)"
        } else {
            cell?.shortcutLabel.stringValue = ""
        }
        
        // Force layout
        cell?.needsLayout = true
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            let rect = tableView.rect(ofRow: row)
            let rectInWindow = tableView.convert(rect, to: nil)
            schedulePreview(for: row, relativeTo: rectInWindow)
            lastHoveredRow = row
        } else {
            previewTask?.cancel()
            previewWindowController.hidePreview()
            lastHoveredRow = -1
        }
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        if row != lastHoveredRow {
            lastHoveredRow = row
            if row >= 0 {
                let rect = tableView.rect(ofRow: row)
                let rectInWindow = tableView.convert(rect, to: nil)
                schedulePreview(for: row, relativeTo: rectInWindow)
            } else {
                previewTask?.cancel()
                previewWindowController.hidePreview()
            }
        }
    }
    
    private func schedulePreview(for row: Int, relativeTo rect: NSRect) {
        previewTask?.cancel()
        if row < 0 || row >= filteredItems.count {
            previewWindowController.hidePreview()
            return
        }
        
        let item = filteredItems[row]
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            guard let self = self, let mainWindow = self.window else { return }
            self.previewWindowController.showPreview(for: item, relativeTo: rect, in: mainWindow)
        }
    }
    
    private func pasteAndHide(row: Int) {
        let item = filteredItems[row]
        pasteToPasteboard(item: item)
        hideWindow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .hidSystemState)
            let cmdVDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
            cmdVDown?.flags = .maskCommand
            let cmdVUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            cmdVUp?.flags = .maskCommand
            
            cmdVDown?.post(tap: .cghidEventTap)
            cmdVUp?.post(tap: .cghidEventTap)
        }
    }
    
    private func pasteToPasteboard(item: (id: Int, content: String, type: String)) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.type == "Image" {
            if let image = NSImage(contentsOfFile: item.content), let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        } else if item.type == "File" {
            let url = URL(fileURLWithPath: item.content)
            pasteboard.setString(url.absoluteString, forType: .fileURL)
        } else {
            pasteboard.setString(item.content, forType: .string)
        }
    }
}
