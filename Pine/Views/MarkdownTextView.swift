//
//  MarkdownTextView.swift
//  Pine
//
//  Created by Luka Kerr on 8/3/19.
//  Copyright © 2019 Luka Kerr. All rights reserved.
//

import Cocoa

class MarkdownTextView: NSTextView {

  private let CONTAINER_INSET: CGFloat = 10.0

  private var overscroll: CGFloat = 0
  private var needsRecompletion: Bool = false
  private var partialAutocompleteWord: String?

  /// Whether typewriter mode is enabled (keeps cursor line centered)
  public var isTypewriterModeEnabled: Bool = false

  private lazy var autocompletionTask = Debouncer(delay: 0, callback: {
    [unowned self] in self.performCompletion()
  })

  override var isContinuousSpellCheckingEnabled: Bool {
    get {
      return preferences[.spellcheckEnabled]
    }

    set {}
  }

  override var textContainerOrigin: NSPoint {
    return NSPoint(x: CONTAINER_INSET, y: CONTAINER_INSET)
  }

  override var rangeForUserCompletion: NSRange {
    var location = cursorLocation - 1

    if location < 0 || location >= self.string.count {
      return NSRange(location: 0, length: 0)
    }

    while !self.string[location].isWhiteSpace {
      if location <= 0 {
        break;
      }

      location -= 1
    }

    if self.string[location].isWhiteSpace {
      location += 1
    }

    return NSRange(location: location, length: cursorLocation - location)
  }

  override func viewDidMoveToWindow() {
    // Setup notification for when scrollview frame changes
    NotificationCenter.receive(.frameDidChange, instance: self, selector: #selector(setOverscroll))
  }

  override func keyDown(with event: NSEvent) {
    if let singleCharacter = event.characters?.first, preferences[.autoPairSyntax] {
      self.pair(character: singleCharacter)
    }

    super.keyDown(with: event)
  }

  override func insertText(_ string: Any, replacementRange: NSRange) {
    super.insertText(string, replacementRange: replacementRange)
    self.autocompletionTask.call()
  }

  override func didChangeText() {
    super.didChangeText()

    if self.needsRecompletion {
      self.needsRecompletion = false
      self.autocompletionTask.call()
    }

    // Notify about cursor position for outline highlighting
    notifyCursorPositionChanged()
  }

  override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
    super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)

    // Notify when selection/cursor changes
    if !stillSelectingFlag {
      notifyCursorPositionChanged()
    }
  }

  private func notifyCursorPositionChanged() {
    let position = selectedRange().location
    NotificationCenter.default.post(
      name: .cursorPositionChanged,
      object: self,
      userInfo: ["position": position]
    )

    // Apply typewriter mode scrolling if enabled
    if isTypewriterModeEnabled {
      centerCurrentLine()
    }
  }

  /// Centers the current line in the visible area (typewriter mode)
  private func centerCurrentLine() {
    guard let scrollView = enclosingScrollView,
          let layoutManager = layoutManager,
          let textContainer = textContainer else { return }

    // Get the glyph range for the current selection
    let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange(), actualCharacterRange: nil)

    // Get the bounding rect for the current line
    let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

    // Calculate the visible rect's center Y
    let visibleRect = scrollView.documentVisibleRect
    let centerY = visibleRect.midY

    // Calculate where the line is relative to the view
    let lineY = lineRect.midY + textContainerOrigin.y

    // Calculate the offset needed to center the line
    let offsetY = lineY - centerY

    // Only scroll if the offset is significant
    if abs(offsetY) > 1 {
      var newOrigin = visibleRect.origin
      newOrigin.y += offsetY

      // Ensure we don't scroll past bounds
      newOrigin.y = max(0, newOrigin.y)
      if let documentHeight = scrollView.documentView?.frame.height {
        newOrigin.y = min(newOrigin.y, documentHeight - visibleRect.height)
      }

      // Animate the scroll
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.1
        context.allowsImplicitAnimation = true
        scrollView.documentView?.scroll(newOrigin)
      }
    }
  }

  override func completions(
    forPartialWordRange charRange: NSRange,
    indexOfSelectedItem index: UnsafeMutablePointer<Int>
  ) -> [String]? {
    let word = (self.string as NSString).substring(with: charRange)

    return autocomplete.getMatches(for: word)
  }

  override func insertCompletion(
    _ word: String,
    forPartialWordRange charRange: NSRange,
    movement: Int,
    isFinal flag: Bool
  ) {
    if self.partialAutocompleteWord == nil {
      self.partialAutocompleteWord = (self.string as NSString).substring(with: charRange)
    }

    var word = word
    var movement = movement

    if flag {
      if let event = self.window?.currentEvent {
        let isKeyDown = event.type == .keyDown
        let containsCommand = event.modifierFlags.contains(.command)

        if isKeyDown && !containsCommand && event.charactersIgnoringModifiers == event.characters {
          if movement == NSRightTextMovement {
            movement = NSIllegalTextMovement
          }

          let isIllegalMovement = movement == NSIllegalTextMovement

          if isIllegalMovement {
            if let character = event.characters?.utf16.first {
              if character < 0xF700, character != UInt16(NSDeleteCharacter) {
                self.needsRecompletion = true
              }
            }
          }
        }
      }

      if [NSIllegalTextMovement, NSRightTextMovement].contains(movement) {
        word = self.partialAutocompleteWord ?? word
      }

      self.partialAutocompleteWord = nil
    }

    super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
  }

  override func paste(_ sender: Any?) {
    let fileURLs = NSPasteboard.general.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: 1]
    ) as? [URL]

    let images = fileURLs?.filter { $0.isImage }

    if let markdownImages = images, markdownImages.count > 0 {
      self.pasteImages(markdownImages)
      return
    }

    super.paste(sender)
  }

  // MARK: - Public methods

  @objc public func setOverscroll() {
    guard
      let font = self.font,
      let scrollView = self.enclosingScrollView,
      let lineHeight = layoutManager?.defaultLineHeight(for: font)
    else { return }

    let ratio: CGFloat = preferences[.scrollPastEnd] ? 0.5 : 0

    let inset = ratio * (scrollView.documentVisibleRect.height - lineHeight)

    self.textContainerInset.height = max(floor(inset / 2), CONTAINER_INSET)
  }

  // MARK: - Private helper methods

  private func pasteImages(_ images: [URL]) {
    for image in images {
      let path = image.absoluteString
      let name = image.lastPathComponent

      self.replace(left: "![\(name)](\(path))\n")
    }
  }

  private func performCompletion() {
    if self.selectedRange.length != 0 || self.hasMarkedText() {
      return
    }

    let nextChar = self.cursorLocation

    if nextChar < self.string.count && !self.string[nextChar].isWhiteSpace {
      return
    }

    complete(self)
  }

}
