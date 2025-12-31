//
//  TableEditorWindowController.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Protocol for table editor delegate
protocol TableEditorDelegate: AnyObject {
  /// Called when the table is updated
  func tableEditor(_ editor: TableEditorWindowController, didUpdate table: MarkdownTable)
  /// Called when editing is cancelled
  func tableEditorDidCancel(_ editor: TableEditorWindowController)
}

/// Window controller for the visual table editor
class TableEditorWindowController: NSWindowController {

  weak var delegate: TableEditorDelegate?

  private var tableEditorVC: TableEditorViewController!
  private var table: MarkdownTable?

  convenience init() {
    let window = TableEditorWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )

    self.init(window: window)

    window.title = "Edit Table"
    window.center()
    window.minSize = NSSize(width: 400, height: 300)

    tableEditorVC = TableEditorViewController()
    tableEditorVC.delegate = self
    window.contentViewController = tableEditorVC
  }

  /// Show the editor with a table
  func showEditor(with table: MarkdownTable) {
    self.table = table
    tableEditorVC.loadTable(table)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  override func close() {
    super.close()
    delegate?.tableEditorDidCancel(self)
  }
}

// MARK: - TableEditorViewControllerDelegate

extension TableEditorWindowController: TableEditorViewControllerDelegate {

  func tableEditorViewController(_ controller: TableEditorViewController, didSave table: MarkdownTable) {
    delegate?.tableEditor(self, didUpdate: table)
    close()
  }

  func tableEditorViewControllerDidCancel(_ controller: TableEditorViewController) {
    close()
  }
}

// MARK: - TableEditorWindow

class TableEditorWindow: NSWindow {

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }
}
