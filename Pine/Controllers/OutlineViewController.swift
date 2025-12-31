//
//  OutlineViewController.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Protocol for outline view delegate
protocol OutlineViewControllerDelegate: AnyObject {
  func outlineViewController(_ controller: OutlineViewController, didSelectItem item: OutlineItem)
  func outlineViewControllerDidRequestRefresh(_ controller: OutlineViewController)
}

/// View controller for the document outline (table of contents)
class OutlineViewController: NSViewController {

  weak var delegate: OutlineViewControllerDelegate?

  private var outlineView: NSOutlineView!
  private var scrollView: NSScrollView!

  /// The parsed outline items
  private var outlineItems: [OutlineItem] = []

  /// Currently highlighted item (based on cursor position)
  private var highlightedItem: OutlineItem?

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
    view.wantsLayer = true

    setupOutlineView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Listen for content changes
    NotificationCenter.receive(.markdownContentChanged, instance: self, selector: #selector(onContentChanged))

    // Listen for cursor position changes
    NotificationCenter.receive(.cursorPositionChanged, instance: self, selector: #selector(onCursorPositionChanged))
  }

  // MARK: - Setup

  private func setupOutlineView() {
    outlineView = NSOutlineView()
    outlineView.headerView = nil
    outlineView.rowHeight = 24
    outlineView.indentationPerLevel = 16
    outlineView.autoresizesOutlineColumn = true
    outlineView.delegate = self
    outlineView.dataSource = self

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("OutlineColumn"))
    column.width = 180
    column.minWidth = 100
    outlineView.addTableColumn(column)
    outlineView.outlineTableColumn = column

    scrollView = NSScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = outlineView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  // MARK: - Public Methods

  /// Update the outline with new markdown content
  /// - Parameter markdown: The markdown text to parse
  func updateOutline(from markdown: String) {
    outlineItems = MarkdownOutlineParser.parse(markdown: markdown)
    outlineView.reloadData()

    // Expand all items by default
    expandAllItems()
  }

  /// Highlight the heading that contains the given cursor position
  /// - Parameter position: The cursor position in the document
  func highlightHeading(at position: Int) {
    guard let item = MarkdownOutlineParser.findHeading(in: outlineItems, containing: position) else {
      highlightedItem = nil
      return
    }

    if highlightedItem != item {
      highlightedItem = item

      // Find and select the row for this item
      let row = outlineView.row(forItem: item)
      if row >= 0 {
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
      }
    }
  }

  /// Clear the outline
  func clearOutline() {
    outlineItems = []
    highlightedItem = nil
    outlineView.reloadData()
  }

  // MARK: - Private Methods

  private func expandAllItems() {
    for item in outlineItems {
      outlineView.expandItem(item, expandChildren: true)
    }
  }

  @objc private func onContentChanged() {
    delegate?.outlineViewControllerDidRequestRefresh(self)
  }

  @objc private func onCursorPositionChanged(_ notification: Notification) {
    if let position = notification.userInfo?["position"] as? Int {
      highlightHeading(at: position)
    }
  }
}

// MARK: - NSOutlineViewDataSource

extension OutlineViewController: NSOutlineViewDataSource {

  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if let outlineItem = item as? OutlineItem {
      return outlineItem.numberOfChildren
    }
    return outlineItems.count
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if let outlineItem = item as? OutlineItem {
      return outlineItem.child(at: index) as Any
    }
    return outlineItems[index]
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let outlineItem = item as? OutlineItem else { return false }
    return outlineItem.hasChildren
  }
}

// MARK: - NSOutlineViewDelegate

extension OutlineViewController: NSOutlineViewDelegate {

  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let outlineItem = item as? OutlineItem else { return nil }

    let cellIdentifier = NSUserInterfaceItemIdentifier("OutlineCell")
    var cellView = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

    if cellView == nil {
      cellView = NSTableCellView()
      cellView?.identifier = cellIdentifier

      let textField = NSTextField(labelWithString: "")
      textField.translatesAutoresizingMaskIntoConstraints = false
      textField.lineBreakMode = .byTruncatingTail
      cellView?.addSubview(textField)
      cellView?.textField = textField

      let imageView = NSImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.imageScaling = .scaleProportionallyDown
      cellView?.addSubview(imageView)
      cellView?.imageView = imageView

      if let cv = cellView {
        NSLayoutConstraint.activate([
          imageView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 2),
          imageView.centerYAnchor.constraint(equalTo: cv.centerYAnchor),
          imageView.widthAnchor.constraint(equalToConstant: 20),
          imageView.heightAnchor.constraint(equalToConstant: 16),

          textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
          textField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -4),
          textField.centerYAnchor.constraint(equalTo: cv.centerYAnchor)
        ])
      }
    }

    cellView?.textField?.stringValue = outlineItem.title

    // Create a simple heading level indicator
    let levelLabel = NSTextField(labelWithString: outlineItem.iconName)
    levelLabel.font = .systemFont(ofSize: 10, weight: .medium)
    levelLabel.textColor = .secondaryLabelColor

    // Use the level indicator as an "image" by setting up a custom attributed string
    cellView?.textField?.font = .systemFont(ofSize: 13 - CGFloat(outlineItem.level - 1))

    return cellView
  }

  func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
    return 24
  }

  func outlineViewSelectionDidChange(_ notification: Notification) {
    guard let item = outlineView.item(atRow: outlineView.selectedRow) as? OutlineItem else { return }

    // Don't trigger navigation if we're just syncing from cursor position
    if item != highlightedItem {
      delegate?.outlineViewController(self, didSelectItem: item)
    }
  }

  func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
    if let outlineItem = item as? OutlineItem {
      outlineItem.isExpanded = true
    }
    return true
  }

  func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
    if let outlineItem = item as? OutlineItem {
      outlineItem.isExpanded = false
    }
    return true
  }
}
