//
//  EditorModeIndicator.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// View that displays the current editor mode in the window
class EditorModeIndicator: NSView {

  /// The current editor mode
  var currentMode: EditorMode = .standard {
    didSet {
      updateDisplay()
    }
  }

  /// Callback when the indicator is clicked
  var onModeClick: (() -> Void)?

  private var iconLabel: NSTextField!
  private var modeLabel: NSTextField!
  private var containerButton: NSButton!

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    wantsLayer = true

    // Create invisible button to handle clicks
    containerButton = NSButton(frame: bounds)
    containerButton.translatesAutoresizingMaskIntoConstraints = false
    containerButton.isBordered = false
    containerButton.title = ""
    containerButton.target = self
    containerButton.action = #selector(indicatorClicked)
    addSubview(containerButton)

    // Create icon label
    iconLabel = NSTextField(labelWithString: currentMode.emoji)
    iconLabel.translatesAutoresizingMaskIntoConstraints = false
    iconLabel.font = .systemFont(ofSize: 11)
    iconLabel.textColor = .secondaryLabelColor
    iconLabel.alignment = .center
    addSubview(iconLabel)

    // Create mode name label
    modeLabel = NSTextField(labelWithString: currentMode.displayName)
    modeLabel.translatesAutoresizingMaskIntoConstraints = false
    modeLabel.font = .systemFont(ofSize: 10)
    modeLabel.textColor = .tertiaryLabelColor
    modeLabel.alignment = .left
    addSubview(modeLabel)

    // Layout constraints
    NSLayoutConstraint.activate([
      containerButton.leadingAnchor.constraint(equalTo: leadingAnchor),
      containerButton.trailingAnchor.constraint(equalTo: trailingAnchor),
      containerButton.topAnchor.constraint(equalTo: topAnchor),
      containerButton.bottomAnchor.constraint(equalTo: bottomAnchor),

      iconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconLabel.widthAnchor.constraint(equalToConstant: 16),

      modeLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 2),
      modeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      modeLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4)
    ])

    // Add hover tracking
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)

    // Add tooltip
    toolTip = "Click to change editor mode"
  }

  private func updateDisplay() {
    iconLabel.stringValue = currentMode.emoji
    modeLabel.stringValue = currentMode.displayName

    // Update tooltip
    toolTip = "Current mode: \(currentMode.displayName)\nClick to change"
  }

  @objc private func indicatorClicked() {
    onModeClick?()
  }

  // MARK: - Mouse Tracking

  override func mouseEntered(with event: NSEvent) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      modeLabel.animator().textColor = .labelColor
      iconLabel.animator().textColor = .labelColor
    }

    // Change cursor to pointing hand
    NSCursor.pointingHand.push()
  }

  override func mouseExited(with event: NSEvent) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      modeLabel.animator().textColor = .tertiaryLabelColor
      iconLabel.animator().textColor = .secondaryLabelColor
    }

    NSCursor.pop()
  }

  override func mouseDown(with event: NSEvent) {
    // Visual feedback on click
    alphaValue = 0.7
  }

  override func mouseUp(with event: NSEvent) {
    alphaValue = 1.0

    // Check if mouse is still inside
    let location = convert(event.locationInWindow, from: nil)
    if bounds.contains(location) {
      indicatorClicked()
    }
  }
}

// MARK: - EditorModeIndicatorViewController

/// View controller for the mode indicator (for use in titlebar accessory)
class EditorModeIndicatorViewController: NSTitlebarAccessoryViewController {

  private var indicator: EditorModeIndicator?

  /// Callback when mode should be changed
  var onModeChangeRequested: (() -> Void)?

  /// Stored mode value for before view is loaded
  private var pendingMode: EditorMode = .standard

  /// Current mode
  var currentMode: EditorMode {
    get { indicator?.currentMode ?? pendingMode }
    set {
      pendingMode = newValue
      indicator?.currentMode = newValue
    }
  }

  override func loadView() {
    let indicatorView = EditorModeIndicator(frame: NSRect(x: 0, y: 0, width: 80, height: 22))
    indicatorView.currentMode = pendingMode
    indicatorView.onModeClick = { [weak self] in
      self?.onModeChangeRequested?()
    }
    indicator = indicatorView
    view = indicatorView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    layoutAttribute = .right
  }
}
