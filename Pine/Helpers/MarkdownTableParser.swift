//
//  MarkdownTableParser.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Parser for detecting and parsing markdown tables
class MarkdownTableParser {

  /// Check if text at the given position contains a markdown table
  /// - Parameters:
  ///   - text: The full markdown text
  ///   - position: The cursor position
  /// - Returns: The parsed MarkdownTable if found, nil otherwise
  static func findTable(in text: String, at position: Int) -> MarkdownTable? {
    let nsText = text as NSString
    let lines = text.components(separatedBy: .newlines)

    // Find which line the cursor is on
    var currentPosition = 0
    var cursorLineIndex = 0

    for (index, line) in lines.enumerated() {
      let lineEnd = currentPosition + line.count
      if position <= lineEnd {
        cursorLineIndex = index
        break
      }
      currentPosition = lineEnd + 1 // +1 for newline
    }

    // Look for table boundaries
    // A table needs at least: header row, separator row, and optionally data rows
    // Find the start and end of the table containing the cursor

    var tableStartLine = -1
    var tableEndLine = -1

    // Look backwards for table start
    for i in stride(from: cursorLineIndex, through: 0, by: -1) {
      let line = lines[i].trimmingCharacters(in: .whitespaces)
      if isTableRow(line) {
        tableStartLine = i
      } else {
        break
      }
    }

    // Look forwards for table end
    for i in cursorLineIndex..<lines.count {
      let line = lines[i].trimmingCharacters(in: .whitespaces)
      if isTableRow(line) {
        tableEndLine = i
      } else {
        break
      }
    }

    guard tableStartLine >= 0 && tableEndLine >= tableStartLine else { return nil }

    // Extract table lines
    let tableLines = Array(lines[tableStartLine...tableEndLine])

    // Need at least header and separator
    guard tableLines.count >= 2 else { return nil }

    // Check if second line is a valid separator
    guard isSeparatorRow(tableLines[1]) else { return nil }

    // Parse the table
    let headers = parseCells(from: tableLines[0])
    let alignments = parseAlignments(from: tableLines[1])

    var rows: [[String]] = []
    for i in 2..<tableLines.count {
      let cells = parseCells(from: tableLines[i])
      // Pad or trim to match header count
      var adjustedCells = cells
      while adjustedCells.count < headers.count {
        adjustedCells.append("")
      }
      if adjustedCells.count > headers.count {
        adjustedCells = Array(adjustedCells.prefix(headers.count))
      }
      rows.append(adjustedCells)
    }

    // Calculate the source range
    var rangeStart = 0
    for i in 0..<tableStartLine {
      rangeStart += lines[i].count + 1 // +1 for newline
    }

    var rangeLength = 0
    for i in tableStartLine...tableEndLine {
      rangeLength += lines[i].count
      if i < tableEndLine {
        rangeLength += 1 // +1 for newline
      }
    }

    let sourceRange = NSRange(location: rangeStart, length: rangeLength)

    // Ensure alignments match headers count
    var adjustedAlignments = alignments
    while adjustedAlignments.count < headers.count {
      adjustedAlignments.append(.left)
    }

    return MarkdownTable(
      headers: headers,
      alignments: adjustedAlignments,
      rows: rows,
      sourceRange: sourceRange
    )
  }

  /// Check if a line looks like a table row
  private static func isTableRow(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("|") || trimmed.contains("|")
  }

  /// Check if a line is a separator row (contains only |, -, :, and whitespace)
  private static func isSeparatorRow(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("-") else { return false }

    // Remove pipes and check remaining characters
    let withoutPipes = trimmed.replacingOccurrences(of: "|", with: "")
    let validChars = CharacterSet(charactersIn: "- :")
    let lineChars = CharacterSet(charactersIn: withoutPipes)

    return validChars.isSuperset(of: lineChars)
  }

  /// Parse cells from a table row
  private static func parseCells(from line: String) -> [String] {
    var cells: [String] = []

    // Remove leading and trailing pipes
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") {
      trimmed = String(trimmed.dropFirst())
    }
    if trimmed.hasSuffix("|") {
      trimmed = String(trimmed.dropLast())
    }

    // Split by pipe
    let parts = trimmed.components(separatedBy: "|")
    for part in parts {
      cells.append(part.trimmingCharacters(in: .whitespaces))
    }

    return cells
  }

  /// Parse alignments from separator row
  private static func parseAlignments(from line: String) -> [ColumnAlignment] {
    let cells = parseCells(from: line)
    return cells.map { ColumnAlignment.from(separator: $0) }
  }
}
