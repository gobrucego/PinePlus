//
//  MarkdownOutlineParser.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Parser for extracting headings from markdown text
class MarkdownOutlineParser {

  /// Regex pattern for matching markdown headings
  /// Matches: # Heading, ## Heading, ### Heading, etc. (up to 6 levels)
  private static let headingPattern = "^(#{1,6})\\s+(.+)$"

  /// Parse markdown text and return a hierarchical list of outline items
  /// - Parameter markdown: The markdown text to parse
  /// - Returns: Array of top-level OutlineItem objects (with nested children)
  static func parse(markdown: String) -> [OutlineItem] {
    let lines = markdown.components(separatedBy: .newlines)
    var allHeadings: [OutlineItem] = []
    var currentPosition = 0

    guard let regex = try? NSRegularExpression(pattern: headingPattern, options: .anchorsMatchLines) else {
      return []
    }

    for line in lines {
      let lineRange = NSRange(location: 0, length: line.utf16.count)
      if let match = regex.firstMatch(in: line, options: [], range: lineRange) {
        // Extract level (number of # characters)
        if let hashRange = Range(match.range(at: 1), in: line),
           let titleRange = Range(match.range(at: 2), in: line) {

          let level = line[hashRange].count
          let title = String(line[titleRange]).trimmingCharacters(in: .whitespaces)

          // Calculate the range in the original document
          let documentRange = NSRange(location: currentPosition, length: line.utf16.count)

          let item = OutlineItem(level: level, title: title, range: documentRange)
          allHeadings.append(item)
        }
      }

      // Move position forward (line length + newline character)
      currentPosition += line.utf16.count + 1
    }

    // Build hierarchical structure
    return buildHierarchy(from: allHeadings)
  }

  /// Build a hierarchical structure from a flat list of headings
  /// - Parameter headings: Flat list of headings in document order
  /// - Returns: Array of top-level headings with nested children
  private static func buildHierarchy(from headings: [OutlineItem]) -> [OutlineItem] {
    var result: [OutlineItem] = []
    var stack: [OutlineItem] = []

    for heading in headings {
      // Pop items from stack that are at same level or lower (higher number)
      while let last = stack.last, last.level >= heading.level {
        stack.removeLast()
      }

      if let parent = stack.last {
        // This heading is a child of the last item on the stack
        parent.addChild(heading)
      } else {
        // This is a top-level heading
        result.append(heading)
      }

      // Push this heading onto the stack
      stack.append(heading)
    }

    return result
  }

  /// Find the heading that contains the given cursor position
  /// - Parameters:
  ///   - outlineItems: The parsed outline items
  ///   - position: The cursor position in the document
  /// - Returns: The OutlineItem containing the position, or nil
  static func findHeading(in outlineItems: [OutlineItem], containing position: Int) -> OutlineItem? {
    // Get all headings in flat order
    let allHeadings = flattenHeadings(outlineItems)

    // Find the heading that precedes or contains this position
    var currentHeading: OutlineItem?
    for heading in allHeadings {
      if heading.range.location <= position {
        currentHeading = heading
      } else {
        break
      }
    }

    return currentHeading
  }

  /// Flatten a hierarchical outline into a flat list in document order
  /// - Parameter items: Hierarchical outline items
  /// - Returns: Flat list of all items
  static func flattenHeadings(_ items: [OutlineItem]) -> [OutlineItem] {
    var result: [OutlineItem] = []

    for item in items {
      result.append(item)
      result.append(contentsOf: flattenHeadings(item.children))
    }

    return result
  }
}
