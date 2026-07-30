# MacCopy

[English](#english) | [中文](#中文)

---

<h2 id="english">English</h2>

MacCopy is a lightning-fast, ultra-lightweight macOS clipboard manager designed as a high-performance alternative to traditional clipboard tools. 

### Features
- **Extreme Performance & Low Memory Footprint**: Built with Swift and pure AppKit (native NSWindow / NSTableView) to minimize overhead.
- **Image & File Support**: Copies, saves, and displays image thumbnails dynamically based on their aspect ratio.
- **Global Shortcuts**: Customizable global hotkeys to summon the clipboard list anywhere.
- **Quick Paste**: Rapidly paste items using `Cmd + 1...9` shortcuts directly from the list.
- **Smart Focus Management**: Automatically hides when clicking outside or switching applications, without stealing focus from your active work.
- **SQLite Database Engine**: Reliable, fast persistence for clipboard history.

### Building and Running
To build and run MacCopy locally, you need macOS 12.0+ and Xcode command-line tools.

```bash
make package
open MacCopy.app
```

### Requirements
- macOS 12.0 or later
- Swift 5.0+

### License
MIT License

---

<h2 id="中文">中文</h2>

MacCopy 是一款极速、超轻量级的 macOS 剪贴板管理工具，旨在作为传统剪贴板应用的高性能替代方案。

### 核心功能
- **极致性能与极低内存占用**：完全使用 Swift 与纯 AppKit（原生 NSWindow / NSTableView）构建，将系统开销降至最低。
- **图片与文件支持**：完美支持复制、保存，并根据原始比例动态显示图片缩略图。
- **全局快捷键**：支持高度自定义的全局快捷键，随时随地呼出剪贴板。
- **快速粘贴**：使用 `Cmd + 1...9` 快捷键，直接从列表中快速粘贴历史记录。
- **智能焦点管理**：当您点击外部区域或切换应用时，面板瞬间自动隐藏，且不会抢夺当前工作应用的键盘焦点。
- **SQLite 数据库引擎**：可靠、极速的剪贴板历史持久化存储。

### 编译与运行
如需在本地编译运行 MacCopy，您需要 macOS 12.0+ 以及 Xcode 命令行工具。

```bash
make package
open MacCopy.app
```

### 系统要求
- macOS 12.0 及更高版本
- Swift 5.0 及以上

### 开源协议
MIT License
