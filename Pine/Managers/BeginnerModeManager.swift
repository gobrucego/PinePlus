//
//  BeginnerModeManager.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Singleton manager for Beginner mode functionality
class BeginnerModeManager {

  /// Shared instance
  static let shared = BeginnerModeManager()

  /// Whether beginner mode is currently active
  private(set) var isActive: Bool = false

  /// Floating toolbar windows for each main window
  private var floatingToolbarWindows: [NSWindow: FloatingFormatToolbarWindow] = [:]

  /// Debounce timer for selection changes
  private var selectionDebounceTimer: Timer?

  private init() {}

  // MARK: - Mode Activation

  /// Activate beginner mode for a window
  /// - Parameter windowController: The window controller to activate beginner mode for
  func activate(for windowController: PineWindowController) {
    guard !isActive else { return }
    isActive = true

    // Create floating toolbar for this window if needed
    if let window = windowController.window {
      _ = getOrCreateToolbarWindow(for: window, windowController: windowController)
    }

    NotificationCenter.send(.editorModeChanged)
  }

  /// Deactivate beginner mode for a window
  /// - Parameter windowController: The window controller to deactivate beginner mode for
  func deactivate(for windowController: PineWindowController) {
    guard isActive else { return }
    isActive = false

    // Hide and remove floating toolbar
    if let window = windowController.window {
      hideToolbar(for: window)
    }

    NotificationCenter.send(.editorModeChanged)
  }

  // MARK: - Floating Toolbar Management

  /// Handle selection change in text view
  /// - Parameters:
  ///   - textView: The text view where selection changed
  ///   - window: The window containing the text view
  func handleSelectionChange(in textView: NSTextView, window: NSWindow) {
    // Only handle if beginner mode is active
    guard isActive, preferences[.beginnerShowFloatingToolbar] else {
      hideToolbar(for: window)
      return
    }

    // Debounce selection changes to avoid flickering
    selectionDebounceTimer?.invalidate()
    selectionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
      self?.updateToolbarForSelection(in: textView, window: window)
    }
  }

  /// Update toolbar position and visibility based on current selection
  private func updateToolbarForSelection(in textView: NSTextView, window: NSWindow) {
    let selectedRange = textView.selectedRange()

    // Only show toolbar if there's an actual selection (not just cursor)
    guard selectedRange.length > 0 else {
      hideToolbar(for: window)
      return
    }

    // Calculate position for toolbar
    guard let toolbarRect = calculateToolbarPosition(for: selectedRange, in: textView) else {
      hideToolbar(for: window)
      return
    }

    // Get or create toolbar window
    guard let windowController = window.windowController as? PineWindowController,
          let toolbarWindow = getOrCreateToolbarWindow(for: window, windowController: windowController) else {
      return
    }

    // Position and show toolbar
    toolbarWindow.setFrameOrigin(toolbarRect.origin)
    showToolbar(for: window)
  }

  /// Calculate the screen position for the floating toolbar
  /// - Parameters:
  ///   - selection: The selection range
  ///   - textView: The text view containing the selection
  /// - Returns: The rect for the toolbar in screen coordinates, or nil if cannot be calculated
  private func calculateToolbarPosition(for selection: NSRange, in textView: NSTextView) -> NSRect? {
    guard let layoutManager = textView.layoutManager,
          let textContainer = textView.textContainer,
          let window = textView.window else {
      return nil
    }

    // Get glyph range for selection
    let glyphRange = layoutManager.glyphRange(forCharacterRange: selection, actualCharacterRange: nil)

    // Get bounding rect for selection
    var selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

    // Adjust for text container origin
    selectionRect.origin.x += textView.textContainerOrigin.x
    selectionRect.origin.y += textView.textContainerOrigin.y

    // Convert to window coordinates
    selectionRect = textView.convert(selectionRect, to: nil)

    // Convert to screen coordinates
    selectionRect = window.convertToScreen(selectionRect)

    // Position toolbar above the selection
    let toolbarHeight: CGFloat = 32
    let toolbarWidth: CGFloat = 240
    let verticalOffset: CGFloat = 8

    var toolbarOrigin = NSPoint(
      x: selectionRect.midX - toolbarWidth / 2,
      y: selectionRect.maxY + verticalOffset
    )

    // Ensure toolbar stays within screen bounds
    if let screen = window.screen {
      let screenFrame = screen.visibleFrame

      // Keep within horizontal bounds
      if toolbarOrigin.x < screenFrame.minX {
        toolbarOrigin.x = screenFrame.minX + 4
      } else if toolbarOrigin.x + toolbarWidth > screenFrame.maxX {
        toolbarOrigin.x = screenFrame.maxX - toolbarWidth - 4
      }

      // If not enough space above, show below selection
      if toolbarOrigin.y + toolbarHeight > screenFrame.maxY {
        toolbarOrigin.y = selectionRect.minY - toolbarHeight - verticalOffset
      }
    }

    return NSRect(x: toolbarOrigin.x, y: toolbarOrigin.y, width: toolbarWidth, height: toolbarHeight)
  }

  /// Get or create the floating toolbar window for a main window
  private func getOrCreateToolbarWindow(for window: NSWindow, windowController: PineWindowController) -> FloatingFormatToolbarWindow? {
    if let existing = floatingToolbarWindows[window] {
      return existing
    }

    let toolbarWindow = FloatingFormatToolbarWindow(windowController: windowController)
    floatingToolbarWindows[window] = toolbarWindow
    window.addChildWindow(toolbarWindow, ordered: .above)

    return toolbarWindow
  }

  /// Show the floating toolbar for a window
  private func showToolbar(for window: NSWindow) {
    guard let toolbarWindow = floatingToolbarWindows[window] else { return }
    if !toolbarWindow.isVisible {
      toolbarWindow.animator().alphaValue = 1.0
      toolbarWindow.orderFront(nil)
    }
  }

  /// Hide the floating toolbar for a window
  private func hideToolbar(for window: NSWindow) {
    guard let toolbarWindow = floatingToolbarWindows[window] else { return }
    if toolbarWindow.isVisible {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.15
        toolbarWindow.animator().alphaValue = 0.0
      }, completionHandler: {
        toolbarWindow.orderOut(nil)
      })
    }
  }

  /// Remove toolbar window when main window closes
  func cleanupToolbar(for window: NSWindow) {
    if let toolbarWindow = floatingToolbarWindows[window] {
      window.removeChildWindow(toolbarWindow)
      toolbarWindow.close()
      floatingToolbarWindows.removeValue(forKey: window)
    }
  }
}
