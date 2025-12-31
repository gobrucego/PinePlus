//
//  CommandPaletteWindowController.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Window controller for the command palette
class CommandPaletteWindowController: NSWindowController {

  private var paletteViewController: CommandPaletteViewController!

  convenience init() {
    let window = CommandPaletteWindow()
    self.init(window: window)

    paletteViewController = CommandPaletteViewController()
    paletteViewController.delegate = self

    window.contentViewController = paletteViewController
    window.delegate = self
  }

  override func showWindow(_ sender: Any?) {
    guard let window = window else { return }

    // Center the window on screen
    centerWindow()

    // Reset search and show
    paletteViewController.resetSearch()

    window.makeKeyAndOrderFront(sender)
    window.makeFirstResponder(paletteViewController.searchField)
  }

  private func centerWindow() {
    guard let window = window, let screen = NSScreen.main else { return }

    let screenFrame = screen.visibleFrame
    let windowFrame = window.frame

    let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
    let y = screenFrame.origin.y + screenFrame.height - windowFrame.height - 150 // Slightly above center

    window.setFrameOrigin(NSPoint(x: x, y: y))
  }

  func dismiss() {
    window?.orderOut(nil)
  }
}

// MARK: - NSWindowDelegate

extension CommandPaletteWindowController: NSWindowDelegate {

  func windowDidResignKey(_ notification: Notification) {
    dismiss()
  }
}

// MARK: - CommandPaletteViewControllerDelegate

extension CommandPaletteWindowController: CommandPaletteViewControllerDelegate {

  func commandPaletteDidSelectCommand(_ command: Command) {
    dismiss()
    command.execute()
  }

  func commandPaletteDidCancel() {
    dismiss()
  }
}

// MARK: - CommandPaletteWindow

/// Custom window for the command palette with specific styling
class CommandPaletteWindow: NSWindow {

  init() {
    let contentRect = NSRect(x: 0, y: 0, width: 500, height: 300)

    super.init(
      contentRect: contentRect,
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    self.isOpaque = false
    self.backgroundColor = .clear
    self.level = .floating
    self.hasShadow = true
    self.isMovableByWindowBackground = false
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // Create visual effect view for background
    let visualEffectView = NSVisualEffectView(frame: contentRect)
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 12
    visualEffectView.layer?.masksToBounds = true

    self.contentView = visualEffectView
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return false
  }

  override func cancelOperation(_ sender: Any?) {
    orderOut(nil)
  }
}
