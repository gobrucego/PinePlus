//
//  CommandRegistry.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Singleton registry for all available commands
class CommandRegistry {
  static let shared = CommandRegistry()

  private(set) var commands: [Command] = []

  private init() {
    registerDefaultCommands()
  }

  /// Register a new command
  func register(_ command: Command) {
    commands.append(command)
  }

  /// Search commands using fuzzy matching
  /// - Parameter query: Search query string
  /// - Returns: Array of matching commands sorted by relevance
  func search(query: String) -> [Command] {
    return FuzzySearch.filter(commands: commands, by: query).map { $0.command }
  }

  /// Get all commands in a specific category
  func commands(in category: CommandCategory) -> [Command] {
    return commands.filter { $0.category == category }
  }

  // MARK: - Default Commands Registration

  private func registerDefaultCommands() {
    // Format commands
    registerFormatCommands()

    // View commands
    registerViewCommands()

    // Export commands
    registerExportCommands()
  }

  private func registerFormatCommands() {
    register(Command(
      id: "format.bold",
      title: "Bold",
      shortcut: "⌘B",
      category: .format,
      action: #selector(MarkdownViewController.bold)
    ))

    register(Command(
      id: "format.italic",
      title: "Italic",
      shortcut: "⌘I",
      category: .format,
      action: #selector(MarkdownViewController.italic)
    ))

    register(Command(
      id: "format.strikethrough",
      title: "Strikethrough",
      shortcut: "⌃`",
      category: .format,
      action: #selector(MarkdownViewController.strikethrough)
    ))

    register(Command(
      id: "format.code",
      title: "Inline Code",
      category: .format,
      action: #selector(MarkdownViewController.code)
    ))

    register(Command(
      id: "format.codeBlock",
      title: "Code Block",
      category: .format,
      action: #selector(MarkdownViewController.codeBlock)
    ))

    register(Command(
      id: "format.h1",
      title: "Heading 1",
      category: .format,
      action: #selector(MarkdownViewController.h1)
    ))

    register(Command(
      id: "format.h2",
      title: "Heading 2",
      category: .format,
      action: #selector(MarkdownViewController.h2)
    ))

    register(Command(
      id: "format.h3",
      title: "Heading 3",
      category: .format,
      action: #selector(MarkdownViewController.h3)
    ))

    register(Command(
      id: "format.h4",
      title: "Heading 4",
      category: .format,
      action: #selector(MarkdownViewController.h4)
    ))

    register(Command(
      id: "format.h5",
      title: "Heading 5",
      category: .format,
      action: #selector(MarkdownViewController.h5)
    ))

    register(Command(
      id: "format.h6",
      title: "Heading 6",
      category: .format,
      action: #selector(MarkdownViewController.h6)
    ))

    register(Command(
      id: "format.math",
      title: "Inline Math",
      category: .format,
      action: #selector(MarkdownViewController.math)
    ))

    register(Command(
      id: "format.mathBlock",
      title: "Math Block",
      category: .format,
      action: #selector(MarkdownViewController.mathBlock)
    ))

    register(Command(
      id: "format.image",
      title: "Insert Image",
      category: .format,
      action: #selector(MarkdownViewController.image)
    ))

    register(Command(
      id: "format.htmlImage",
      title: "Insert HTML Image",
      category: .format,
      action: #selector(MarkdownViewController.HTMLImage)
    ))
  }

  private func registerViewCommands() {
    register(Command(
      id: "view.togglePreview",
      title: "Toggle Preview",
      shortcut: "⌘\\",
      category: .view,
      action: #selector(PineWindowController.togglePreview)
    ))

    register(Command(
      id: "view.toggleEditor",
      title: "Toggle Editor",
      shortcut: "⌘|",
      category: .view,
      action: #selector(PineWindowController.toggleEditor)
    ))

    register(Command(
      id: "view.toggleSidebar",
      title: "Toggle Sidebar",
      shortcut: "⌘L",
      category: .view,
      action: #selector(SidebarViewController.toggleSidebar)
    ))
  }

  private func registerExportCommands() {
    register(Command(
      id: "export.pdf",
      title: "Export as PDF",
      category: .export,
      action: #selector(PineWindowController.exportPDF)
    ))

    register(Command(
      id: "export.html",
      title: "Export as HTML",
      category: .export,
      action: #selector(PineWindowController.exportHTML)
    ))

    register(Command(
      id: "export.latex",
      title: "Export as LaTeX",
      category: .export,
      action: #selector(PineWindowController.exportLatex)
    ))

    register(Command(
      id: "export.xml",
      title: "Export as XML",
      category: .export,
      action: #selector(PineWindowController.exportXML)
    ))

    register(Command(
      id: "export.txt",
      title: "Export as Plain Text",
      category: .export,
      action: #selector(PineWindowController.exportTXT)
    ))
  }
}

/// Global access to the command registry
let commandRegistry = CommandRegistry.shared
