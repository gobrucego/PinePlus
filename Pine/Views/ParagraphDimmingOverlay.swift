//
//  ParagraphDimmingOverlay.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Cocoa

/// Overlay view that dims everything except the focused paragraph
class ParagraphDimmingOverlay: NSView {

  /// The rect of the currently focused paragraph (in view coordinates)
  var focusedParagraphRect: NSRect? {
    didSet {
      needsDisplay = true
    }
  }

  /// The dimming color (semi-transparent background)
  var dimmingColor: NSColor {
    let opacity = preferences[.zenDimmingOpacity]
    return NSColor.black.withAlphaComponent(opacity)
  }

  override var isFlipped: Bool {
    return true
  }

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
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard let focusRect = focusedParagraphRect else {
      // If no focused paragraph, don't draw anything
      return
    }

    // Create the dimming path (entire bounds minus focused area)
    let path = NSBezierPath(rect: bounds)
    path.windingRule = .evenOdd

    // Add the clear area (focused paragraph) with some padding
    let paddedFocusRect = focusRect.insetBy(dx: -10, dy: -5)
    let focusPath = NSBezierPath(roundedRect: paddedFocusRect, xRadius: 4, yRadius: 4)
    path.append(focusPath)

    // Draw the dimming overlay
    dimmingColor.setFill()
    path.fill()
  }

  /// Update the focused paragraph based on cursor position
  /// - Parameters:
  ///   - textView: The text view containing the text
  ///   - cursorLocation: The cursor position in the text
  func updateFocusedParagraph(in textView: NSTextView, cursorLocation: Int) {
    guard let layoutManager = textView.layoutManager,
          let textContainer = textView.textContainer,
          let scrollView = textView.enclosingScrollView,
          cursorLocation <= textView.string.count else {
      focusedParagraphRect = nil
      return
    }

    let text = textView.string as NSString

    // Get the paragraph range containing the cursor
    let paragraphRange = text.paragraphRange(for: NSRange(location: cursorLocation, length: 0))

    // Convert character range to glyph range
    let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)

    // Get the bounding rect for the paragraph in textView coordinates
    var paragraphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

    // Adjust for text container origin
    paragraphRect.origin.x += textView.textContainerOrigin.x
    paragraphRect.origin.y += textView.textContainerOrigin.y

    // Convert from document coordinates to visible (scrollView) coordinates
    // The overlay is positioned relative to the scrollView's visible area,
    // so we need to subtract the scroll offset
    let visibleRect = scrollView.documentVisibleRect

    var overlayRect = paragraphRect
    overlayRect.origin.x -= visibleRect.origin.x
    overlayRect.origin.y -= visibleRect.origin.y

    // Only show if the paragraph is at least partially visible
    let visibleBounds = NSRect(origin: .zero, size: visibleRect.size)
    if overlayRect.intersects(visibleBounds) {
      focusedParagraphRect = overlayRect
    } else {
      focusedParagraphRect = nil
    }
  }
}
