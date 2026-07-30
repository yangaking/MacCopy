# MacCopy

MacCopy is a lightning-fast, ultra-lightweight macOS clipboard manager designed as a high-performance alternative to traditional clipboard tools. 

## Features
- **Extreme Performance & Low Memory Footprint**: Built with Swift and pure AppKit (native NSWindow / NSTableView) to minimize overhead.
- **Image & File Support**: Copies, saves, and displays image thumbnails dynamically based on their aspect ratio.
- **Global Shortcuts**: Customizable global hotkeys to summon the clipboard list anywhere.
- **Quick Paste**: Rapidly paste items using `Cmd + 1...9` shortcuts directly from the list.
- **Smart Focus Management**: Automatically hides when clicking outside or switching applications, without stealing focus from your active work.
- **SQLite Database Engine**: Reliable, fast persistence for clipboard history.

## Building and Running
To build and run MacCopy locally, you need macOS 12.0+ and Xcode command-line tools.

```bash
make package
open MacCopy.app
```

## Requirements
- macOS 12.0 or later
- Swift 5.0+

## License
MIT License
