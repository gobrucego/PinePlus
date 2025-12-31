//
//  Command.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Represents a command that can be executed from the command palette
struct Command {
  let id: String
  let title: String
  let shortcut: String?
  let category: CommandCategory
  let action: Selector
  let target: AnyObject?

  init(
    id: String,
    title: String,
    shortcut: String? = nil,
    category: CommandCategory,
    action: Selector,
    target: AnyObject? = nil
  ) {
    self.id = id
    self.title = title
    self.shortcut = shortcut
    self.category = category
    self.action = action
    self.target = target
  }

  /// Execute this command
  func execute() {
    NSApp.sendAction(action, to: target, from: nil)
  }
}

/// Categories for organizing commands
enum CommandCategory: String, CaseIterable {
  case format = "Format"
  case view = "View"
  case file = "File"
  case export = "Export"
  case edit = "Edit"

  var displayName: String {
    return rawValue
  }

  var icon: NSImage? {
    switch self {
    case .format:
      return NSImage(named: NSImage.fontPanelName)
    case .view:
      return NSImage(named: NSImage.quickLookTemplateName)
    case .file:
      return NSImage(named: NSImage.folderName)
    case .export:
      return NSImage(named: NSImage.shareTemplateName)
    case .edit:
      return NSImage(named: NSImage.touchBarTextItalicTemplateName)
    }
  }
}
