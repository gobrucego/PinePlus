//
//  ZenModeState.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Stores the state of UI elements before entering Zen mode
/// so they can be restored when exiting
class ZenModeState {

  /// Whether Zen mode is currently active
  var isActive: Bool = false

  /// UI states saved before entering Zen mode
  var sidebarWasVisible: Bool = true
  var previewWasVisible: Bool = true
  var toolbarWasVisible: Bool = true
  var titlebarWasVisible: Bool = true

  /// Zen mode features
  var typewriterModeEnabled: Bool = true
  var paragraphFocusEnabled: Bool = true

  /// Reset to defaults
  func reset() {
    isActive = false
    sidebarWasVisible = true
    previewWasVisible = true
    toolbarWasVisible = true
    titlebarWasVisible = true
  }

  /// Save current UI state before entering Zen mode
  func saveState(sidebarVisible: Bool, previewVisible: Bool, toolbarVisible: Bool, titlebarVisible: Bool) {
    sidebarWasVisible = sidebarVisible
    previewWasVisible = previewVisible
    toolbarWasVisible = toolbarVisible
    titlebarWasVisible = titlebarVisible
  }
}
