//
//  FloatingFormatToolbar.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Format types available in the floating toolbar
enum FormatType {
  case bold
  case italic
  case strikethrough
  case link
  case code
  case heading(level: Int)
}

/// Protocol for floating toolbar delegate
protocol FloatingFormatToolbarDelegate: AnyObject {
  func floatingToolbar(_ toolbar: FloatingFormatToolbar, didSelectFormat format: FormatType)
}

// MARK: - FloatingFormatToolbarWindow

/// The floating window that contains the format toolbar
class FloatingFormatToolbarWindow: NSWindow {

  private weak var pineWindowController: PineWindowController?
  private var formatToolbar: FloatingFormatToolbar!

  init(windowController: PineWindowController) {
    self.pineWindowController = windowController

    let contentRect = NSRect(x: 0, y: 0, width: 240, height: 32)

    super.init(
      contentRect: contentRect,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    setupWindow()
    setupFormatToolbar()
  }

  private func setupWindow() {
    isOpaque = false
    backgroundColor = .clear
    level = .floating
    hasShadow = true
    isMovableByWindowBackground = false
    ignoresMouseEvents = false
    alphaValue = 0.0 // Start hidden

    // Make sure it can receive mouse events
    acceptsMouseMovedEvents = true
  }

  private func setupFormatToolbar() {
    // Create visual effect background
    let visualEffectView = NSVisualEffectView(frame: contentView!.bounds)
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 8
    visualEffectView.layer?.masksToBounds = true
    visualEffectView.autoresizingMask = [.width, .height]

    contentView = visualEffectView

    // Create toolbar view
    formatToolbar = FloatingFormatToolbar(frame: visualEffectView.bounds)
    formatToolbar.autoresizingMask = [.width, .height]
    formatToolbar.delegate = self
    visualEffectView.addSubview(formatToolbar)
  }

  override var canBecomeKey: Bool { return false }
  override var canBecomeMain: Bool { return false }
}

// MARK: - FloatingFormatToolbarWindow + FloatingFormatToolbarDelegate

extension FloatingFormatToolbarWindow: FloatingFormatToolbarDelegate {

  func floatingToolbar(_ toolbar: FloatingFormatToolbar, didSelectFormat format: FormatType) {
    guard let markdownVC = pineWindowController?.markdownViewController else { return }

    // Apply the format
    switch format {
    case .bold:
      markdownVC.markdownTextView.replace(left: "**", right: "**")
    case .italic:
      markdownVC.markdownTextView.replace(left: "_", right: "_")
    case .strikethrough:
      markdownVC.markdownTextView.replace(left: "~~", right: "~~")
    case .link:
      markdownVC.markdownTextView.replace(left: "[", right: "]()")
    case .code:
      markdownVC.markdownTextView.replace(left: "`", right: "`")
    case .heading(let level):
      let prefix = String(repeating: "#", count: level) + " "
      markdownVC.markdownTextView.replace(left: prefix, atLineStart: true)
    }

    // Hide toolbar after applying format
    if let parentWindow = parent {
      BeginnerModeManager.shared.handleSelectionChange(
        in: markdownVC.markdownTextView,
        window: parentWindow
      )
    }
  }
}

// MARK: - FloatingFormatToolbar

/// The toolbar view containing format buttons
class FloatingFormatToolbar: NSView {

  weak var delegate: FloatingFormatToolbarDelegate?

  /// Button configuration
  private struct ButtonConfig {
    let title: String
    let format: FormatType
    let tooltip: String
    let isBold: Bool

    init(title: String, format: FormatType, tooltip: String, isBold: Bool = false) {
      self.title = title
      self.format = format
      self.tooltip = tooltip
      self.isBold = isBold
    }
  }

  private let buttons: [ButtonConfig] = [
    ButtonConfig(title: "B", format: .bold, tooltip: "Bold (⌘B)", isBold: true),
    ButtonConfig(title: "I", format: .italic, tooltip: "Italic (⌘I)"),
    ButtonConfig(title: "S", format: .strikethrough, tooltip: "Strikethrough"),
    ButtonConfig(title: "🔗", format: .link, tooltip: "Insert Link (⌘K)"),
    ButtonConfig(title: "</>", format: .code, tooltip: "Inline Code"),
    ButtonConfig(title: "H1", format: .heading(level: 1), tooltip: "Heading 1"),
    ButtonConfig(title: "H2", format: .heading(level: 2), tooltip: "Heading 2"),
  ]

  private var buttonViews: [NSButton] = []
  private var headingMenu: NSMenu?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupButtons()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupButtons()
  }

  private func setupButtons() {
    let stackView = NSStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.orientation = .horizontal
    stackView.spacing = 2
    stackView.distribution = .fillEqually
    stackView.alignment = .centerY
    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
    ])

    for config in buttons {
      let button = createButton(for: config)
      buttonViews.append(button)
      stackView.addArrangedSubview(button)
    }
  }

  private func createButton(for config: ButtonConfig) -> NSButton {
    let button = NSButton()
    button.title = config.title
    button.bezelStyle = .texturedRounded
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = 4

    // Font styling
    if config.isBold {
      button.font = .boldSystemFont(ofSize: 12)
    } else {
      button.font = .systemFont(ofSize: 11)
    }

    // Tooltip
    button.toolTip = config.tooltip

    // Tag to identify the button
    button.tag = buttons.firstIndex(where: { $0.title == config.title }) ?? 0

    // Action
    button.target = self
    button.action = #selector(buttonClicked(_:))

    // Hover effect
    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: button,
      userInfo: nil
    )
    button.addTrackingArea(trackingArea)

    return button
  }

  @objc private func buttonClicked(_ sender: NSButton) {
    guard sender.tag < buttons.count else { return }
    let config = buttons[sender.tag]
    delegate?.floatingToolbar(self, didSelectFormat: config.format)
  }

  // MARK: - Mouse Tracking for Hover Effects

  override func mouseEntered(with event: NSEvent) {
    if let button = event.trackingArea?.owner as? NSButton {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.1
        button.animator().layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
      }
    }
  }

  override func mouseExited(with event: NSEvent) {
    if let button = event.trackingArea?.owner as? NSButton {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.1
        button.animator().layer?.backgroundColor = NSColor.clear.cgColor
      }
    }
  }
}
