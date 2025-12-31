//
//  TableEditorViewController.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Protocol for table editor view controller delegate
protocol TableEditorViewControllerDelegate: AnyObject {
  func tableEditorViewController(_ controller: TableEditorViewController, didSave table: MarkdownTable)
  func tableEditorViewControllerDidCancel(_ controller: TableEditorViewController)
}

/// View controller for editing markdown tables
class TableEditorViewController: NSViewController {

  weak var delegate: TableEditorViewControllerDelegate?

  private var table: MarkdownTable?
  private var tableView: NSTableView!
  private var scrollView: NSScrollView!
  private var toolbar: NSView!

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    view.wantsLayer = true

    setupToolbar()
    setupTableView()
    setupButtons()
  }

  // MARK: - Setup

  private func setupToolbar() {
    toolbar = NSView()
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toolbar)

    // Add Row button
    let addRowBtn = NSButton(title: "+ Row", target: self, action: #selector(addRow))
    addRowBtn.bezelStyle = .rounded
    addRowBtn.translatesAutoresizingMaskIntoConstraints = false

    // Add Column button
    let addColBtn = NSButton(title: "+ Column", target: self, action: #selector(addColumn))
    addColBtn.bezelStyle = .rounded
    addColBtn.translatesAutoresizingMaskIntoConstraints = false

    // Remove Row button
    let removeRowBtn = NSButton(title: "- Row", target: self, action: #selector(removeRow))
    removeRowBtn.bezelStyle = .rounded
    removeRowBtn.translatesAutoresizingMaskIntoConstraints = false

    // Remove Column button
    let removeColBtn = NSButton(title: "- Column", target: self, action: #selector(removeColumn))
    removeColBtn.bezelStyle = .rounded
    removeColBtn.translatesAutoresizingMaskIntoConstraints = false

    toolbar.addSubview(addRowBtn)
    toolbar.addSubview(addColBtn)
    toolbar.addSubview(removeRowBtn)
    toolbar.addSubview(removeColBtn)

    NSLayoutConstraint.activate([
      toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
      toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      toolbar.heightAnchor.constraint(equalToConstant: 30),

      addRowBtn.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
      addRowBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

      addColBtn.leadingAnchor.constraint(equalTo: addRowBtn.trailingAnchor, constant: 8),
      addColBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

      removeRowBtn.leadingAnchor.constraint(equalTo: addColBtn.trailingAnchor, constant: 16),
      removeRowBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

      removeColBtn.leadingAnchor.constraint(equalTo: removeRowBtn.trailingAnchor, constant: 8),
      removeColBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor)
    ])
  }

  private func setupTableView() {
    tableView = NSTableView()
    tableView.delegate = self
    tableView.dataSource = self
    tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
    tableView.usesAlternatingRowBackgroundColors = true
    tableView.allowsColumnReordering = false
    tableView.allowsColumnResizing = true
    tableView.rowHeight = 24

    scrollView = NSScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.borderType = .bezelBorder
    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
    ])
  }

  private var saveButton: NSButton!
  private var cancelButton: NSButton!

  private func setupButtons() {
    // Cancel button
    cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelEditing))
    cancelButton.bezelStyle = .rounded
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    cancelButton.keyEquivalent = "\u{1b}" // Escape key

    // Save button
    saveButton = NSButton(title: "Save", target: self, action: #selector(saveTable))
    saveButton.bezelStyle = .rounded
    saveButton.translatesAutoresizingMaskIntoConstraints = false
    saveButton.keyEquivalent = "\r" // Return key

    view.addSubview(cancelButton)
    view.addSubview(saveButton)

    // Button height constant for proper layout
    let buttonHeight: CGFloat = 24

    NSLayoutConstraint.activate([
      saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
      saveButton.widthAnchor.constraint(equalToConstant: 80),
      saveButton.heightAnchor.constraint(equalToConstant: buttonHeight),

      cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
      cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
      cancelButton.widthAnchor.constraint(equalToConstant: 80),
      cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight)
    ])
  }

  // MARK: - Public Methods

  func loadTable(_ table: MarkdownTable) {
    self.table = table
    rebuildColumns()
    tableView.reloadData()
  }

  // MARK: - Private Methods

  private func rebuildColumns() {
    guard let table = table else { return }

    // Remove existing columns
    while let column = tableView.tableColumns.first {
      tableView.removeTableColumn(column)
    }

    // Add columns based on table headers
    for (index, header) in table.headers.enumerated() {
      let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column\(index)"))
      column.title = header
      column.width = 120
      column.minWidth = 50
      column.isEditable = true
      tableView.addTableColumn(column)
    }
  }

  // MARK: - Actions

  @objc private func addRow() {
    table?.appendRow()
    tableView.reloadData()
  }

  @objc private func addColumn() {
    table?.appendColumn(header: "Column")
    rebuildColumns()
    tableView.reloadData()
  }

  @objc private func removeRow() {
    guard let table = table else { return }
    let selectedRow = tableView.selectedRow
    if selectedRow >= 0 && selectedRow < table.rowCount {
      table.removeRow(at: selectedRow)
      tableView.reloadData()
    }
  }

  @objc private func removeColumn() {
    guard let table = table else { return }
    let selectedColumn = tableView.selectedColumn
    if selectedColumn >= 0 && selectedColumn < table.columnCount {
      table.removeColumn(at: selectedColumn)
      rebuildColumns()
      tableView.reloadData()
    }
  }

  @objc private func saveTable() {
    guard let table = table else { return }
    delegate?.tableEditorViewController(self, didSave: table)
  }

  @objc private func cancelEditing() {
    delegate?.tableEditorViewControllerDidCancel(self)
  }
}

// MARK: - NSTableViewDataSource

extension TableEditorViewController: NSTableViewDataSource {

  func numberOfRows(in tableView: NSTableView) -> Int {
    // +1 for header row
    return (table?.rowCount ?? 0) + 1
  }
}

// MARK: - NSTableViewDelegate

extension TableEditorViewController: NSTableViewDelegate {

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let table = table, let tableColumn = tableColumn else { return nil }

    let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn) ?? 0

    let cellIdentifier = NSUserInterfaceItemIdentifier("TableCell")
    var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

    if cellView == nil {
      cellView = NSTableCellView()
      cellView?.identifier = cellIdentifier

      let textField = NSTextField()
      textField.isBordered = false
      textField.drawsBackground = false
      textField.isEditable = true
      textField.translatesAutoresizingMaskIntoConstraints = false
      textField.delegate = self
      cellView?.addSubview(textField)
      cellView?.textField = textField

      if let cv = cellView {
        NSLayoutConstraint.activate([
          textField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 2),
          textField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -2),
          textField.centerYAnchor.constraint(equalTo: cv.centerYAnchor)
        ])
      }
    }

    // Row 0 is header, rest are data rows
    if row == 0 {
      // Header row
      cellView?.textField?.stringValue = columnIndex < table.headers.count ? table.headers[columnIndex] : ""
      cellView?.textField?.font = .boldSystemFont(ofSize: 12)
    } else {
      // Data row
      let dataRowIndex = row - 1
      if dataRowIndex < table.rows.count && columnIndex < table.rows[dataRowIndex].count {
        cellView?.textField?.stringValue = table.rows[dataRowIndex][columnIndex]
      } else {
        cellView?.textField?.stringValue = ""
      }
      cellView?.textField?.font = .systemFont(ofSize: 12)
    }

    // Store row/column info in tag for editing
    cellView?.textField?.tag = row * 1000 + columnIndex

    return cellView
  }
}

// MARK: - NSTextFieldDelegate

extension TableEditorViewController: NSTextFieldDelegate {

  func controlTextDidEndEditing(_ obj: Notification) {
    guard let textField = obj.object as? NSTextField,
          let table = table else { return }

    let tag = textField.tag
    let row = tag / 1000
    let column = tag % 1000

    if row == 0 {
      // Editing header
      if column < table.headers.count {
        table.headers[column] = textField.stringValue
        // Update column title
        if column < tableView.tableColumns.count {
          tableView.tableColumns[column].title = textField.stringValue
        }
      }
    } else {
      // Editing data cell
      let dataRowIndex = row - 1
      table.setCell(row: dataRowIndex, column: column, value: textField.stringValue)
    }
  }
}
