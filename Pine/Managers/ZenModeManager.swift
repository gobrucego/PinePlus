//
//  ZenModeManager.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Singleton manager for Zen mode functionality
class ZenModeManager {

  /// Shared instance
  static let shared = ZenModeManager()

  /// Current state
  private(set) var state = ZenModeState()

  /// Whether Zen mode is active
  var isActive: Bool {
    return state.isActive
  }

  private init() {}

  /// Toggle Zen mode on/off
  /// - Parameter windowController: The window controller to apply Zen mode to
  func toggle(for windowController: PineWindowController) {
    if state.isActive {
      exitZenMode(for: windowController)
    } else {
      enterZenMode(for: windowController)
    }
  }

  /// Enter Zen mode
  /// - Parameter windowController: The window controller to apply Zen mode to
  func enterZenMode(for windowController: PineWindowController) {
    guard !state.isActive else { return }

    let window = windowController.window

    // Save current UI state
    let sidebarVisible = !windowController.sidebarIsHidden
    let previewVisible = !windowController.previewIsHidden
    let toolbarVisible = window?.toolbar?.isVisible ?? false
    let titlebarVisible = window?.titlebarAppearsTransparent == false

    state.saveState(
      sidebarVisible: sidebarVisible,
      previewVisible: previewVisible,
      toolbarVisible: toolbarVisible,
      titlebarVisible: titlebarVisible
    )

    // Apply Zen mode settings from preferences
    if preferences[.zenHideSidebar] {
      windowController.setSidebarVisibility(hidden: true)
    }

    if preferences[.zenHidePreview] {
      windowController.setPreviewVisibility(hidden: true)
    }

    if preferences[.zenHideToolbar] {
      window?.toolbar?.isVisible = false
    }

    // Enter full screen if not already
    if !(window?.styleMask.contains(.fullScreen) ?? false) {
      window?.toggleFullScreen(nil)
    }

    // Enable typewriter mode if preference is set
    if preferences[.zenTypewriterMode] {
      enableTypewriterMode(for: windowController)
    }

    // Enable paragraph focus if preference is set
    if preferences[.zenParagraphFocus] {
      enableParagraphFocus(for: windowController)
    }

    state.isActive = true

    // Notify about Zen mode change
    NotificationCenter.send(.zenModeToggled)
  }

  /// Exit Zen mode
  /// - Parameter windowController: The window controller to restore
  func exitZenMode(for windowController: PineWindowController) {
    guard state.isActive else { return }

    let window = windowController.window

    // Restore saved UI state
    windowController.setSidebarVisibility(hidden: !state.sidebarWasVisible)
    windowController.setPreviewVisibility(hidden: !state.previewWasVisible)

    if state.toolbarWasVisible {
      window?.toolbar?.isVisible = true
    }

    // Exit full screen if we entered it
    if window?.styleMask.contains(.fullScreen) ?? false {
      window?.toggleFullScreen(nil)
    }

    // Disable typewriter mode
    disableTypewriterMode(for: windowController)

    // Disable paragraph focus
    disableParagraphFocus(for: windowController)

    state.reset()

    // Notify about Zen mode change
    NotificationCenter.send(.zenModeToggled)
  }

  // MARK: - Typewriter Mode

  private func enableTypewriterMode(for windowController: PineWindowController) {
    guard let markdownVC = windowController.markdownViewController else { return }
    markdownVC.markdownTextView.isTypewriterModeEnabled = true
  }

  private func disableTypewriterMode(for windowController: PineWindowController) {
    guard let markdownVC = windowController.markdownViewController else { return }
    markdownVC.markdownTextView.isTypewriterModeEnabled = false
  }

  // MARK: - Paragraph Focus

  private func enableParagraphFocus(for windowController: PineWindowController) {
    guard let markdownVC = windowController.markdownViewController else { return }
    markdownVC.enableParagraphFocus()
  }

  private func disableParagraphFocus(for windowController: PineWindowController) {
    guard let markdownVC = windowController.markdownViewController else { return }
    markdownVC.disableParagraphFocus()
  }
}
