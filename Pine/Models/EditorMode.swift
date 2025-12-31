//
//  EditorMode.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Defines the available editor modes in PinePlus
enum EditorMode: Int, CaseIterable {
  /// Beginner mode with floating toolbar and helpful guides
  case beginner = 0
  /// Standard mode for experienced users
  case standard = 1
  /// Zen mode for distraction-free writing
  case zen = 2

  /// Display name for the mode
  var displayName: String {
    switch self {
    case .beginner: return "Beginner"
    case .standard: return "Standard"
    case .zen: return "Zen"
    }
  }

  /// Localized display name
  var localizedName: String {
    switch self {
    case .beginner: return NSLocalizedString("Beginner", comment: "Beginner mode name")
    case .standard: return NSLocalizedString("Standard", comment: "Standard mode name")
    case .zen: return NSLocalizedString("Zen", comment: "Zen mode name")
    }
  }

  /// Icon for the mode (using SF Symbols names for macOS 11+, fallback to emoji)
  var icon: String {
    switch self {
    case .beginner: return "graduationcap"
    case .standard: return "doc.text"
    case .zen: return "leaf"
    }
  }

  /// Emoji fallback for older systems
  var emoji: String {
    switch self {
    case .beginner: return "🎓"
    case .standard: return "📝"
    case .zen: return "🧘"
    }
  }

  /// Description of the mode
  var description: String {
    switch self {
    case .beginner:
      return NSLocalizedString(
        "Beginner mode shows a floating format toolbar when you select text, making it easy to learn Markdown.",
        comment: "Beginner mode description"
      )
    case .standard:
      return NSLocalizedString(
        "Standard mode provides a clean editing experience for experienced users.",
        comment: "Standard mode description"
      )
    case .zen:
      return NSLocalizedString(
        "Zen mode minimizes distractions with typewriter scrolling and paragraph focus.",
        comment: "Zen mode description"
      )
    }
  }

  /// Keyboard shortcut number for this mode
  var shortcutNumber: String {
    return "\(rawValue + 1)"
  }

  /// Create EditorMode from saved preference value
  static func from(rawValue: Int) -> EditorMode {
    return EditorMode(rawValue: rawValue) ?? .standard
  }
}
