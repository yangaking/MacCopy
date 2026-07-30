import AppKit

class PreviewWindowController: NSWindowController {
    private let imageView = NSImageView()
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    
    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        
        super.init(window: window)
        
        let visualEffect = NSVisualEffectView(frame: window.contentRect(forFrameRect: window.frame))
        visualEffect.material = .menu
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.autoresizingMask = [.width, .height]
        window.contentView = visualEffect
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = visualEffect.bounds.insetBy(dx: 10, dy: 10)
        imageView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(imageView)
        
        scrollView.frame = visualEffect.bounds.insetBy(dx: 10, dy: 10)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        scrollView.documentView = textView
        
        visualEffect.addSubview(scrollView)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func showPreview(for item: (id: Int, content: String, type: String), relativeTo rect: NSRect, in mainWindow: NSWindow) {
        guard let window = window else { return }
        
        var targetSize = NSSize(width: 300, height: 300)
        
        if item.type == "Image" {
            scrollView.isHidden = true
            imageView.isHidden = false
            if let image = NSImage(contentsOfFile: item.content) {
                imageView.image = image
                
                // Calculate proportional size, max 400x400
                var size = image.size
                let maxDim: CGFloat = 400
                if size.width > maxDim || size.height > maxDim {
                    let ratio = min(maxDim / size.width, maxDim / size.height)
                    size.width *= ratio
                    size.height *= ratio
                }
                // add padding
                size.width += 20
                size.height += 20
                targetSize = size
            }
        } else {
            imageView.isHidden = true
            scrollView.isHidden = false
            let displayContent = item.content
            textView.string = displayContent
            
            // Adjust height based on text content length
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
            let rect = (displayContent as NSString).boundingRect(with: NSSize(width: 280, height: CGFloat.greatestFiniteMagnitude),
                                                                 options: .usesLineFragmentOrigin,
                                                                 attributes: attributes,
                                                                 context: nil)
            var height = rect.height + 20
            if height > 400 { height = 400 }
            if height < 100 { height = 100 }
            targetSize = NSSize(width: 300, height: height)
        }
        
        window.setContentSize(targetSize)
        
        // Convert the row rect to screen coordinates
        let screenRect = mainWindow.convertToScreen(rect)
        
        // Decide placement: right or left of the main window
        if let screen = mainWindow.screen {
            var origin = NSPoint(x: mainWindow.frame.maxX + 10, y: screenRect.maxY)
            if origin.x + targetSize.width > screen.visibleFrame.maxX {
                // Not enough space on the right, place on the left
                origin.x = mainWindow.frame.minX - targetSize.width - 10
            }
            if origin.y < screen.visibleFrame.minY {
                origin.y = screen.visibleFrame.minY + 10
            }
            window.setFrameTopLeftPoint(origin)
        }
        
        window.orderFront(nil)
    }
    
    func hidePreview() {
        window?.orderOut(nil)
    }
}
