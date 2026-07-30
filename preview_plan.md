# UI Optimization Plan

## 1. Fix Shortcut Label Visibility on White Background
**Problem**: In Dark Mode, `NSVisualEffectView` with `.behindWindow` blending over a white background becomes too light, making white text (`textColor`) and gray text (`secondaryLabelColor`) illegible.
**Solution**: 
- Change `visualEffect.material` from `.popover` to `.menu`. This ensures the visual effect matches the system menu bar's robust contrast.
- Alternatively, force `appearance = NSAppearance(named: .vibrantDark)` if we want a consistent dark theme, but `.menu` is more native.
- Ensure `customTextField` and `shortcutLabel` use appropriate semantic colors that contrast well with the `.menu` material.

## 2. Dynamic Image Sizing
**Problem**: Images are currently forced into a 24x24 or 20x20 square.
**Solution**:
- Implement `tableView(_:heightOfRow:)` in `SearchWindowController`.
- Return `30` for Text/File rows.
- Return `60` (or dynamically calculate up to a max height) for Image rows.
- In `CustomTableCellView.layout()`, for images: 
  - Set `customImageView.imageAlignment = .alignLeft`
  - Set `customImageView.frame` to fill the available height (e.g., `bounds.height - 10`) and a proportional width, or just give it a large bounding box and let `.alignLeft` and `.scaleProportionallyUpOrDown` handle it.

## 3. Hover and Selection Preview
**Problem**: No preview for long text or images.
**Solution**:
- Create a `PreviewWindowController` (a borderless `NSPanel` with a visual effect view, an `NSImageView`, and an `NSTextField` for scrollable text).
- **Selection**: In `tableViewSelectionDidChange`, determine the currently selected row. Show the `PreviewWindowController` positioned to the right of the `SearchWindow`.
- **Hover**: Add a `NSTrackingArea` to `CustomTableCellView` to detect `mouseEntered`. When the mouse enters a cell, show the preview for that cell. When `mouseExited`, hide it (or switch to the selected row's preview).
- Ensure the preview panel is `.nonactivatingPanel` and does not interfere with the global focus dismissal.

## Open Questions
- Do you want the preview window to appear instantly, or with a slight delay (e.g., 0.5s) to avoid flashing when scrolling rapidly? (Recommendation: 0.3s - 0.5s delay).
