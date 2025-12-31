//
//  CommandPaletteViewController.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Delegate protocol for command palette actions
protocol CommandPaletteViewControllerDelegate: AnyObject {
  func commandPaletteDidSelectCommand(_ command: Command)
  func commandPaletteDidCancel()
}

/// View controller for the command palette UI
class CommandPaletteViewController: NSViewController {

  weak var delegate: CommandPaletteViewControllerDelegate?

  private(set) var searchField: NSTextField!
  private var tableView: NSTableView!
  private var scrollView: NSScrollView!

  private var filteredCommands: [Command] = []

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
    view.wantsLayer = true

    setupSearchField()
    setupTableView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Load all commands initially
    filteredCommands = commandRegistry.commands
    tableView.reloadData()
  }

  // MARK: - Setup

  private var separatorLine: NSBox!

  private func setupSearchField() {
    searchField = NSTextField(frame: .zero)
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.placeholderString = "Type a command..."
    searchField.font = .systemFont(ofSize: 18)
    searchField.focusRingType = .none
    searchField.isBordered = false
    searchField.drawsBackground = false
    searchField.delegate = self

    view.addSubview(searchField)

    NSLayoutConstraint.activate([
      searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      searchField.heightAnchor.constraint(equalToConstant: 30)
    ])

    // Add separator line
    separatorLine = NSBox()
    separatorLine.translatesAutoresizingMaskIntoConstraints = false
    separatorLine.boxType = .separator

    view.addSubview(separatorLine)

    NSLayoutConstraint.activate([
      separatorLine.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
      separatorLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      separatorLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      separatorLine.heightAnchor.constraint(equalToConstant: 1)
    ])
  }

  private func setupTableView() {
    tableView = NSTableView(frame: .zero)
    tableView.headerView = nil
    tableView.rowHeight = 36
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .regular
    tableView.delegate = self
    tableView.dataSource = self

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
    column.width = 468
    tableView.addTableColumn(column)

    scrollView = NSScrollView(frame: .zero)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 8),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  // MARK: - Public Methods

  func resetSearch() {
    searchField.stringValue = ""
    filteredCommands = commandRegistry.commands
    tableView.reloadData()

    if !filteredCommands.isEmpty {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }
  }

  // MARK: - Private Methods

  private func filterCommands(with query: String) {
    if query.isEmpty {
      filteredCommands = commandRegistry.commands
    } else {
      filteredCommands = commandRegistry.search(query: query)
    }

    tableView.reloadData()

    if !filteredCommands.isEmpty {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }
  }

  private func executeSelectedCommand() {
    let selectedRow = tableView.selectedRow
    guard selectedRow >= 0 && selectedRow < filteredCommands.count else { return }

    let command = filteredCommands[selectedRow]
    delegate?.commandPaletteDidSelectCommand(command)
  }

  private func moveSelection(by delta: Int) {
    let newRow = tableView.selectedRow + delta
    guard newRow >= 0 && newRow < filteredCommands.count else { return }

    tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
    tableView.scrollRowToVisible(newRow)
  }
}

// MARK: - NSTextFieldDelegate

extension CommandPaletteViewController: NSTextFieldDelegate {

  func controlTextDidChange(_ obj: Notification) {
    filterCommands(with: searchField.stringValue)
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(moveUp(_:)) {
      moveSelection(by: -1)
      return true
    } else if commandSelector == #selector(moveDown(_:)) {
      moveSelection(by: 1)
      return true
    } else if commandSelector == #selector(insertNewline(_:)) {
      executeSelectedCommand()
      return true
    } else if commandSelector == #selector(cancelOperation(_:)) {
      delegate?.commandPaletteDidCancel()
      return true
    }
    return false
  }
}

// MARK: - NSTableViewDataSource

extension CommandPaletteViewController: NSTableViewDataSource {

  func numberOfRows(in tableView: NSTableView) -> Int {
    return filteredCommands.count
  }
}

// MARK: - NSTableViewDelegate

extension CommandPaletteViewController: NSTableViewDelegate {

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard row < filteredCommands.count else { return nil }

    let command = filteredCommands[row]

    let cellIdentifier = NSUserInterfaceItemIdentifier("CommandCell")
    var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? CommandPaletteCellView

    if cellView == nil {
      cellView = CommandPaletteCellView()
      cellView?.identifier = cellIdentifier
    }

    cellView?.configure(with: command)
    return cellView
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    // Selection changed, could add visual feedback here
  }

  func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
    return true
  }
}

// MARK: - CommandPaletteCellView

/// Custom cell view for displaying a command in the palette
class CommandPaletteCellView: NSTableCellView {

  private var titleLabel: NSTextField!
  private var shortcutLabel: NSTextField!
  private var categoryLabel: NSTextField!

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupViews()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupViews()
  }

  private func setupViews() {
    titleLabel = NSTextField(labelWithString: "")
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = .systemFont(ofSize: 14)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail

    shortcutLabel = NSTextField(labelWithString: "")
    shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
    shortcutLabel.font = .systemFont(ofSize: 12)
    shortcutLabel.textColor = .secondaryLabelColor
    shortcutLabel.alignment = .right

    categoryLabel = NSTextField(labelWithString: "")
    categoryLabel.translatesAutoresizingMaskIntoConstraints = false
    categoryLabel.font = .systemFont(ofSize: 11)
    categoryLabel.textColor = .tertiaryLabelColor

    addSubview(titleLabel)
    addSubview(shortcutLabel)
    addSubview(categoryLabel)

    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: categoryLabel.leadingAnchor, constant: -8),

      categoryLabel.trailingAnchor.constraint(equalTo: shortcutLabel.leadingAnchor, constant: -12),
      categoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      categoryLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

      shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      shortcutLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
    ])
  }

  func configure(with command: Command) {
    titleLabel.stringValue = command.title
    shortcutLabel.stringValue = command.shortcut ?? ""
    categoryLabel.stringValue = command.category.displayName
  }
}
