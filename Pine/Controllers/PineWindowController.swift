//
//  PineWindowController.swift
//  Pine
//
//  Created by Luka Kerr on 25/4/18.
//  Copyright © 2018 Luka Kerr. All rights reserved.
//

import Cocoa

let AUTOSAVE_NAME = "PineWindow"

class PineWindowController: NSWindowController, NSWindowDelegate {

  private var toolbar: NSToolbar?
  private var toolbarData = ToolbarData()

  private var titlebarAccessoryController: NSTitlebarAccessoryViewController!

  // Editor Mode
  private var modeIndicatorController: EditorModeIndicatorViewController?
  private(set) var currentEditorMode: EditorMode = .standard

  /// The split view controller containing the SidebarViewController and editor split view controller
  private var mainSplitViewController: NSSplitViewController? {
    return contentViewController as? NSSplitViewController
  }

  /// The split view controller containing the MarkdownViewController and PreviewViewController
  private var editorSplitViewController: NSSplitViewController? {
    return mainSplitViewController?.splitViewItems.last?.viewController as? NSSplitViewController
  }

  /// The sidebar view controller
  private var sidebarViewController: SidebarViewController? {
    return mainSplitViewController?.splitViewItems.first?.viewController as? SidebarViewController
  }

  /// The markdown view controller instance for this window (public for Zen mode)
  public var markdownViewController: MarkdownViewController? {
    return editorSplitViewController?.splitViewItems.first?.viewController as? MarkdownViewController
  }

  /// The preview view controller instance for this window
  private var previewViewController: PreviewViewController? {
    return editorSplitViewController?.splitViewItems.last?.viewController as? PreviewViewController
  }

  /// Whether the sidebar is currently hidden
  public var sidebarIsHidden: Bool {
    return sidebarViewController?.sidebarIsHidden ?? true
  }

  /// Whether the preview is currently hidden
  public var previewIsHidden: Bool {
    return editorSplitViewController?.splitViewItems.last?.isCollapsed ?? true
  }

  override var acceptsFirstResponder: Bool {
    return true
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    // Setup notification observer for preferences change
    NotificationCenter.receive(.preferencesChanged, instance: self, selector: #selector(reloadUI))

    self.window?.setFrameAutosaveName(AUTOSAVE_NAME)

    // Set word count label in titlebar
    titlebarAccessoryController = storyboard?.instantiateController(
      withIdentifier: "titlebarViewController"
    ) as? NSTitlebarAccessoryViewController

    titlebarAccessoryController.layoutAttribute = .right
    window?.addTitlebarAccessoryViewController(titlebarAccessoryController)

    // Setup mode indicator
    setupModeIndicator()

    // Apply saved editor mode on load
    let savedModeValue = preferences[.editorMode]
    let savedMode = EditorMode.from(rawValue: savedModeValue)
    if savedMode == .beginner {
      BeginnerModeManager.shared.activate(for: self)
    }

    reloadUI()
  }

  override func showWindow(_ sender: Any?) {
    super.showWindow(sender)

    // Sync window sidebar after window becomes visible
    self.syncWindowSidebars()
  }

  private func setupToolbar() {
    toolbar = NSToolbar(identifier: "PineToolbar")
    toolbar?.delegate = self
    toolbar?.isVisible = true
    toolbar?.displayMode = .iconOnly
    toolbar?.allowsUserCustomization = true
    toolbar?.autosavesConfiguration = true

    window?.toolbar = toolbar
  }

  @objc private func reloadUI() {
    if preferences[.showToolbar] {
      self.setupToolbar()
    } else {
      window?.toolbar = nil
    }
  }

  func windowWillClose(_ notification: Notification) {
    // When a window is closed, a document is removed from the sidebar
    if let url = (document as? Document)?.fileURL {
      openDocuments.remove(itemWithUrl: url)
      syncWindowSidebars()
    }

    // Cleanup beginner mode toolbar
    if let window = window {
      BeginnerModeManager.shared.cleanupToolbar(for: window)
    }
  }

  public func syncWindowSidebars() {
    // Hacky way to get all sidebars and syncronize the sidebar data
    // Map over all windows (tabs) and find the sidebar
    getVisibleWindows().forEach {
      ($0.windowController as? PineWindowController)?.sidebarViewController?.sync()
    }
  }

  public func changeDocument(file: URL) {
    // Check if document is already open in a tab first
    for window in getVisibleWindows() {
      guard let doc = window.windowController?.document as? Document else { continue }

      if doc.fileURL == file {
        window.makeKeyAndOrderFront(nil)
        syncWindowSidebars()
        return
      }
    }

    // Otherwise open document in current tab
    (DocumentController.shared as? DocumentController)?.replaceCurrentDocument(with: file)
  }

  // MARK: - First responder methods called by NSMenuItems applicable to the current window

  @IBAction func togglePreview(sender: NSMenuItem) {
    guard let preview = editorSplitViewController?.splitViewItems.last else { return }

    preview.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
    preview.animator().isCollapsed = !preview.isCollapsed

    // If the preview is open after toggling, send a notification to re-generate the preview
    if !preview.isCollapsed {
      NotificationCenter.send(.markdownContentChanged)
    }

    if let svc = sidebarViewController {
      svc.setSidebarVisibility(hidden: svc.sidebarIsHidden)
    }
  }

  @IBAction func toggleEditor(sender: NSMenuItem) {
    guard let editor = editorSplitViewController?.splitViewItems.first else { return }

    editor.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
    editor.animator().isCollapsed = !editor.isCollapsed
  }

  // MARK: - Visibility Control Methods

  /// Set the sidebar visibility
  /// - Parameter hidden: Whether to hide the sidebar
  public func setSidebarVisibility(hidden: Bool) {
    sidebarViewController?.setSidebarVisibility(hidden: hidden)
  }

  /// Set the preview visibility
  /// - Parameter hidden: Whether to hide the preview
  public func setPreviewVisibility(hidden: Bool) {
    guard let preview = editorSplitViewController?.splitViewItems.last else { return }
    preview.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
    preview.animator().isCollapsed = hidden
  }

  // MARK: - Zen Mode

  /// Toggle Zen mode on/off
  @IBAction func toggleZenMode(sender: NSMenuItem) {
    ZenModeManager.shared.toggle(for: self)
  }

  // MARK: - Editor Mode

  /// Set the editor mode
  /// - Parameter mode: The mode to switch to
  public func setEditorMode(_ mode: EditorMode) {
    let previousMode = currentEditorMode
    guard mode != previousMode else { return }

    currentEditorMode = mode

    // Handle mode transitions
    switch mode {
    case .beginner:
      BeginnerModeManager.shared.activate(for: self)
      if previousMode == .zen {
        ZenModeManager.shared.exitZenMode(for: self)
      }

    case .standard:
      BeginnerModeManager.shared.deactivate(for: self)
      if previousMode == .zen {
        ZenModeManager.shared.exitZenMode(for: self)
      }

    case .zen:
      BeginnerModeManager.shared.deactivate(for: self)
      ZenModeManager.shared.enterZenMode(for: self)
    }

    // Update mode indicator
    modeIndicatorController?.currentMode = mode

    // Save preference
    preferences[.editorMode] = mode.rawValue

    // Notify about mode change
    NotificationCenter.send(.editorModeChanged)
  }

  /// Setup the mode indicator in the titlebar
  private func setupModeIndicator() {
    guard preferences[.beginnerShowModeIndicator] else { return }

    let controller = EditorModeIndicatorViewController()
    controller.onModeChangeRequested = { [weak self] in
      self?.showModeMenu()
    }

    // Load saved mode
    let savedModeValue = preferences[.editorMode]
    currentEditorMode = EditorMode.from(rawValue: savedModeValue)
    controller.currentMode = currentEditorMode

    modeIndicatorController = controller
    window?.addTitlebarAccessoryViewController(controller)
  }

  /// Show the mode selection menu
  private func showModeMenu() {
    let menu = NSMenu()

    for mode in EditorMode.allCases {
      let item = NSMenuItem(
        title: "\(mode.emoji) \(mode.displayName)",
        action: #selector(modeMenuItemClicked(_:)),
        keyEquivalent: mode.shortcutNumber
      )
      item.keyEquivalentModifierMask = [.command, .control]
      item.tag = mode.rawValue
      item.state = (mode == currentEditorMode) ? .on : .off
      item.target = self
      menu.addItem(item)
    }

    // Show menu at indicator location
    if let indicatorView = modeIndicatorController?.view {
      let location = NSPoint(x: 0, y: indicatorView.bounds.height)
      menu.popUp(positioning: nil, at: location, in: indicatorView)
    }
  }

  /// Handle mode menu item selection
  @objc private func modeMenuItemClicked(_ sender: NSMenuItem) {
    guard let mode = EditorMode(rawValue: sender.tag) else { return }
    setEditorMode(mode)
  }

  /// Actions for menu items
  @objc func setBeginnerMode(_ sender: Any?) {
    setEditorMode(.beginner)
  }

  @objc func setStandardMode(_ sender: Any?) {
    setEditorMode(.standard)
  }

  @objc func setZenModeFromMenu(_ sender: Any?) {
    setEditorMode(.zen)
  }

  // MARK: - Public static helper methods

  /// Returns the current window's document path
  public static func getCurrentDocument() -> String? {
    guard
      let window = NSApp.keyWindow?.windowController as? PineWindowController,
      let doc = window.document as? Document
    else { return nil }

    return doc.fileURL?.relativePath
  }

  // MARK: - Private helper functions

  private func getVisibleWindows() -> [NSWindow] {
    return NSApplication.shared.windows.filter { $0.isVisible }
  }

}

extension PineWindowController: NSToolbarDelegate {

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard
      let toolbarItemInfo = toolbarData.toolbarItems.filter({ $0.identifier == itemIdentifier }).first
    else { return nil }

    var toolbarItem: NSToolbarItem

    if toolbarItemInfo.isSegmented, let children = toolbarItemInfo.children, let title = toolbarItemInfo.title {
      let segmented = ToolbarSegmentedControl(segments: children)

      let items: [NSToolbarItem] = children.enumerated().map { (index, child) in
        if let icon = child.icon, let image = NSImage(named: icon) {
          segmented.setImage(image, forSegment: index)
          segmented.setWidth(40, forSegment: index)
        } else if let iconTitle = child.iconTitle {
          segmented.setLabel(iconTitle, forSegment: index)
        }

        return makeToolbarItem(using: child)
      }

      let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)
      group.paletteLabel = title
      group.subitems = items
      group.view = segmented

      toolbarItem = group
    } else {
      toolbarItem = makeToolbarItem(using: toolbarItemInfo)
    }

    return toolbarItem
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return toolbarData.uniqueToolbarIdentifiers
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return toolbarData.toolbarIdentifiers
  }

  private func makeToolbarItem(using item: ToolbarItemInfo) -> NSToolbarItem {
    let toolbarItem = NSToolbarItem(itemIdentifier: item.identifier)

    if let title = item.title {
      toolbarItem.label = title
    }

    let button = NSButton()
    button.bezelStyle = .texturedRounded
    button.action = item.action

    if let icon = item.icon {
      let image = NSImage(named: icon)
      button.image = image
    } else if let iconTitle = item.iconTitle {
      button.title = iconTitle
    }

    toolbarItem.view = button

    return toolbarItem
  }

}

extension PineWindowController {

  // MARK: - First responder methods for exporting

  @IBAction func exportPDF(sender: NSMenuItem) {
    PDFExporter.export(from: markdownViewController)
  }

  @IBAction func exportHTML(sender: NSMenuItem) {
    HTMLExporter.export(from: previewViewController?.webPreview)
  }

  @IBAction func exportLatex(sender: NSMenuItem) {
    LatexExporter.export(from: markdownViewController?.markdownTextView)
  }

  @IBAction func exportXML(sender: NSMenuItem) {
    XMLExporter.export(from: markdownViewController?.markdownTextView)
  }

  @IBAction func exportTXT(sender: NSMenuItem) {
    TXTExporter.export(from: markdownViewController?.markdownTextView)
  }

}
