//
//  OutlineItem.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Represents a heading in the document outline
class OutlineItem {
  /// Heading level (1-6 for H1-H6)
  let level: Int

  /// The heading text content
  let title: String

  /// The range of this heading in the document
  let range: NSRange

  /// Child headings (nested under this heading)
  var children: [OutlineItem] = []

  /// Parent heading (nil for top-level headings)
  weak var parent: OutlineItem?

  /// Whether this item is expanded in the outline view
  var isExpanded: Bool = true

  init(level: Int, title: String, range: NSRange, parent: OutlineItem? = nil) {
    self.level = level
    self.title = title
    self.range = range
    self.parent = parent
  }

  /// Add a child heading
  func addChild(_ child: OutlineItem) {
    child.parent = self
    children.append(child)
  }

  /// Get the number of children
  var numberOfChildren: Int {
    return children.count
  }

  /// Check if this item has children
  var hasChildren: Bool {
    return !children.isEmpty
  }

  /// Get child at index
  func child(at index: Int) -> OutlineItem? {
    guard index >= 0 && index < children.count else { return nil }
    return children[index]
  }

  /// Get the display icon name based on heading level
  var iconName: String {
    return "H\(level)"
  }
}

// MARK: - Equatable

extension OutlineItem: Equatable {
  static func == (lhs: OutlineItem, rhs: OutlineItem) -> Bool {
    return lhs.level == rhs.level &&
           lhs.title == rhs.title &&
           lhs.range == rhs.range
  }
}
