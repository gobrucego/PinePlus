//
//  SidebarViewController.swift
//  Pine
//
//  Created by Luka Kerr on 24/6/18.
//  Copyright © 2018 Luka Kerr. All rights reserved.
//

import Cocoa

/// Sidebar tab options
enum SidebarTab: Int {
  case files = 0
  case outline = 1
}

class SidebarViewController: NSViewController {

  @IBOutlet weak private var sidebar: NSOutlineView!
  @IBOutlet weak private var sidebarActionsView: NSView!

  // Tab switching
  private var tabControl: NSSegmentedControl!
  private var containerView: NSView!
  private var outlineViewController: OutlineViewController?
  private var currentTab: SidebarTab = .files

  // Data used for sidebar rows
  var items: [FileSystemItem] = []

  // Whether the sidebar's structure has been synced yet
  // The structure is only set once on first load
  var structureHasSynced: Bool = false

  // Whether to ignore the next row selection
  var ignoreNextSelection: Bool = false

  public var sidebarIsHidden: Bool {
    return sidebarSplitViewItem?.isCollapsed ?? true
  }

  /// The split view item holding this sidebar view controller
  private var sidebarSplitViewItem: NSSplitViewItem? {
    return (parent as? NSSplitViewController)?.splitViewItems.first
  }

  /// The sidebar view's window controller
  private var windowController: PineWindowController? {
    return view.window?.windowController as? PineWindowController
  }

  override func viewWillAppear() {
    updateSidebarAppearance()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Setup notification observer for preference and appearance changes
    NotificationCenter.receive(.preferencesChanged, instance: self, selector: #selector(updateSidebarAppearance))
    NotificationCenter.receive(.appearanceChanged, instance: self, selector: #selector(updateSidebarAppearance))

    // Setup selector for when row in sidebar is double clicked
    sidebar.doubleAction = #selector(doubleClicked)

    // Setup the contextual menus for sidebar items
    setupContextualMenu()

    // Setup tab control and outline view
    setupTabControl()
    setupOutlineViewController()
  }

  // MARK: - Tab Control Setup

  private func setupTabControl() {
    // Create segmented control for tab switching
    tabControl = NSSegmentedControl(labels: ["Files", "Outline"], trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
    tabControl.selectedSegment = 0
    tabControl.translatesAutoresizingMaskIntoConstraints = false
    tabControl.segmentStyle = .texturedSquare
    tabControl.segmentDistribution = .fillEqually

    // Create container view for holding the active view
    containerView = NSView()
    containerView.translatesAutoresizingMaskIntoConstraints = false

    // Add tab control to the view hierarchy (above sidebar actions view)
    // Insert at the top of the sidebar's parent view
    if let parentView = sidebar.superview?.superview {
      parentView.addSubview(tabControl)

      NSLayoutConstraint.activate([
        tabControl.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 8),
        tabControl.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -8),
        tabControl.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 8),
        tabControl.heightAnchor.constraint(equalToConstant: 24)
      ])
    }
  }

  private func setupOutlineViewController() {
    outlineViewController = OutlineViewController()
    outlineViewController?.delegate = self
  }

  @objc private func tabChanged(_ sender: NSSegmentedControl) {
    let newTab = SidebarTab(rawValue: sender.selectedSegment) ?? .files
    switchToTab(newTab)
  }

  private func switchToTab(_ tab: SidebarTab) {
    guard tab != currentTab else { return }
    currentTab = tab

    switch tab {
    case .files:
      showFilesView()
    case .outline:
      showOutlineView()
    }
  }

  private func showFilesView() {
    sidebar.isHidden = false
    outlineViewController?.view.removeFromSuperview()
  }

  private func showOutlineView() {
    sidebar.isHidden = true

    guard let outlineVC = outlineViewController else { return }

    // Add outline view to the same parent as sidebar
    if let parentView = sidebar.superview {
      outlineVC.view.translatesAutoresizingMaskIntoConstraints = false
      parentView.addSubview(outlineVC.view)

      // Account for tab control height (24) + padding (8 top + 8 bottom = 16)
      // Tab is in grandparent, so outline needs offset from top of its parent
      let tabAreaHeight: CGFloat = 40

      NSLayoutConstraint.activate([
        outlineVC.view.topAnchor.constraint(equalTo: parentView.topAnchor, constant: tabAreaHeight),
        outlineVC.view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
        outlineVC.view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
        outlineVC.view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
      ])
    }

    // Request content update
    refreshOutlineContent()
  }

  /// Update the outline view with current document content
  public func updateOutline(with markdown: String) {
    outlineViewController?.updateOutline(from: markdown)
  }

  /// Refresh outline content from current document
  private func refreshOutlineContent() {
    guard let doc = windowController?.document as? Document,
          let markdown = doc.markdownVC?.getContent() else { return }
    updateOutline(with: markdown)
  }

  public func sync() {
    items = openDocuments.getDocuments()
    sidebar.reloadData()

    if !structureHasSynced {
      syncSidebarStructure()
      structureHasSynced = true
    }

    syncSelectedRow()
  }

  public func setSidebarVisibility(hidden: Bool) {
    sidebarSplitViewItem?.isCollapsed = hidden
  }

  @IBAction func toggleSidebar(_ sender: NSButton) {
    sidebarSplitViewItem?.isCollapsed.toggle()
  }

  // MARK: - Private functions for controlling the sidebar view UI

  /// Sync the expanded/collapsed structure of the sidebar
  private func syncSidebarStructure() {
    var row = 0

    // A while loop is used since when an item is expanded,
    // the numberOfRows increases and must be recalculated
    while row < sidebar.numberOfRows {
      guard
        let rowItem = sidebar.item(atRow: row) as? FileSystemItem
      else { continue }

      syncItemStructure(rowItem)

      row += 1
    }
  }

  /// Recursive function that when given an item, expands it
  /// and all of its nested children, if necessary
  private func syncItemStructure(_ item: FileSystemItem) {
    if item.isExpanded {
      sidebar.expandItem(item)
    } else {
      return
    }

    let childIndexes = item.getNumberOfChildren() - 1

    guard childIndexes >= 0 else { return }

    for index in 0...childIndexes {
      let child = item.getChild(at: index)

      if child.isExpanded {
        sidebar.expandItem(child)
        syncItemStructure(child)
      }
    }
  }

  private func syncSelectedRow() {
    let doc = windowController?.document as? Document

    var selectedRow: Int?

    for row in IndexSet(integersIn: 0..<sidebar.numberOfRows) {
      let rowItem = sidebar.item(atRow: row) as? FileSystemItem

      if rowItem?.fullPath == doc?.fileURL?.relativePath {
        selectedRow = row
      }
    }

    if let selected = selectedRow {
      ignoreNextSelection = true
      sidebar.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
    }
  }

  /// Set a contextual menu (called on right click) for the sidebar
  private func setupContextualMenu() {
    let menu = NSMenu()
    menu.delegate = self

    let removeItem = NSMenuItem()
    removeItem.title = "Remove from sidebar"
    removeItem.action = #selector(removeItemFromSidebar)

    menu.addItem(removeItem)
    sidebar.menu = menu
  }

  // MARK: - Private functions for updating the sidebar and its rows

  /// Called when the 'remove from sidebar' NSMenuItem is clicked
  @objc private func removeItemFromSidebar(_ sender: NSMenuItem) {
    guard
      let itemToRemove = sidebar.item(atRow: sidebar.clickedRow) as? FileSystemItem
    else { return }

    openDocuments.remove(item: itemToRemove)
    windowController?.syncWindowSidebars()
  }

  /// Called when the a row in the sidebar is double clicked
  @objc private func doubleClicked(_ sender: Any?) {
    let clickedRow = sidebar.item(atRow: sidebar.clickedRow)

    if sidebar.isItemExpanded(clickedRow) {
      sidebar.collapseItem(clickedRow)
    } else {
      sidebar.expandItem(clickedRow)
    }
  }

  /// Update the sidebar appearance based on any preferences and the theme
  @objc private func updateSidebarAppearance() {
    sidebar.appearance = NSAppearance(named: .current)
    sidebarActionsView.appearance = NSAppearance(named: .current)
    sidebarSplitViewItem?.isCollapsed = !preferences[.showSidebar]

    var backgroundColor: NSColor = .clear

    if preferences[.useThemeColorForSidebar] && !preferences[.useSystemAppearance] {
      backgroundColor = theme.background
    }

    sidebar.backgroundColor = backgroundColor
    sidebarActionsView.setBackgroundColor(backgroundColor)
  }

}

extension SidebarViewController: NSOutlineViewDataSource {

  // Number of items in the sidebar
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    guard let item = item as? FileSystemItem else { return items.count }
    return item.getNumberOfChildren()
  }

  // Items to be added to sidebar
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    guard let item = item as? FileSystemItem else { return items[index] }
    return item.getChild(at: index)
  }

  // Whether rows are expandable by an arrow
  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let item = item as? FileSystemItem else { return false }
    return item.getNumberOfChildren() != 0
  }

  // Height of each row
  func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
    return 30.0
  }

  // When a row is clicked on should it be selected
  func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
    return true
  }

  // Whether the row should be expanded
  func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
    guard let item = item as? FileSystemItem else { return false }

    item.isExpanded = true

    return true
  }

  // Whether a row should be collapsed
  func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
    guard let item = item as? FileSystemItem else { return false }

    item.isExpanded = false

    return true
  }

  // When a row is selected
  func outlineViewSelectionDidChange(_ notification: Notification) {
    if ignoreNextSelection {
      ignoreNextSelection = false
      return
    }

    guard let doc = sidebar.item(atRow: sidebar.selectedRow) as? FileSystemItem else { return }

    if doc.isDirectory { return }

    windowController?.changeDocument(file: doc.fileURL)
  }

  /// The NSTableRowView instance to be used
  func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
    return SidebarTableRowView(frame: .zero)
  }

}

extension SidebarViewController: NSOutlineViewDelegate {

  // Create a cell given an item and set its properties
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let item = item as? FileSystemItem else { return nil }

    let view = outlineView.makeView(
      withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ItemCell"),
      owner: self
    ) as? NSTableCellView

    view?.textField?.stringValue = item.getName()

    if item.isDirectory {
      view?.imageView?.image = NSImage(named: "Folder")
    } else {
      view?.imageView?.image = NSImage(named: "Markdown")
    }

    return view
  }

}

extension SidebarViewController: NSMenuDelegate {

  /// Called when the menu is about to open.
  /// If the clicked item is not a top level item, we cancel the menu
  func menuWillOpen(_ menu: NSMenu) {
    guard
      let itemToRemove = sidebar.item(atRow: sidebar.clickedRow) as? FileSystemItem
    else { return }

    if !openDocuments.contains(itemToRemove) {
      menu.cancelTracking()
    }
  }

}

// MARK: - OutlineViewControllerDelegate

extension SidebarViewController: OutlineViewControllerDelegate {

  func outlineViewController(_ controller: OutlineViewController, didSelectItem item: OutlineItem) {
    // Navigate to the selected heading in the document
    guard let doc = windowController?.document as? Document,
          let markdownVC = doc.markdownVC else { return }

    markdownVC.scrollToRange(item.range)
  }

  func outlineViewControllerDidRequestRefresh(_ controller: OutlineViewController) {
    refreshOutlineContent()
  }

}
