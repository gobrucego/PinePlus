//
//  MarkdownTable.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Column alignment options for markdown tables
enum ColumnAlignment {
  case left
  case center
  case right

  /// Convert to markdown separator format
  var markdownSeparator: String {
    switch self {
    case .left:
      return ":---"
    case .center:
      return ":---:"
    case .right:
      return "---:"
    }
  }

  /// Parse from separator string
  static func from(separator: String) -> ColumnAlignment {
    let trimmed = separator.trimmingCharacters(in: .whitespaces)
    let hasLeftColon = trimmed.hasPrefix(":")
    let hasRightColon = trimmed.hasSuffix(":")

    if hasLeftColon && hasRightColon {
      return .center
    } else if hasRightColon {
      return .right
    } else {
      return .left
    }
  }
}

/// Represents a markdown table
class MarkdownTable {

  /// Header row cells
  var headers: [String]

  /// Column alignments
  var alignments: [ColumnAlignment]

  /// Data rows (array of rows, each row is array of cells)
  var rows: [[String]]

  /// The range of this table in the source document
  var sourceRange: NSRange

  init(headers: [String], alignments: [ColumnAlignment], rows: [[String]], sourceRange: NSRange) {
    self.headers = headers
    self.alignments = alignments
    self.rows = rows
    self.sourceRange = sourceRange
  }

  /// Number of columns
  var columnCount: Int {
    return headers.count
  }

  /// Number of data rows (excluding header)
  var rowCount: Int {
    return rows.count
  }

  // MARK: - Row Operations

  /// Add a new row at the specified index
  func insertRow(at index: Int) {
    let emptyRow = Array(repeating: "", count: columnCount)
    rows.insert(emptyRow, at: min(index, rows.count))
  }

  /// Append a new row at the end
  func appendRow() {
    let emptyRow = Array(repeating: "", count: columnCount)
    rows.append(emptyRow)
  }

  /// Remove a row at the specified index
  func removeRow(at index: Int) {
    guard index >= 0 && index < rows.count else { return }
    rows.remove(at: index)
  }

  /// Move a row from one index to another
  func moveRow(from sourceIndex: Int, to destinationIndex: Int) {
    guard sourceIndex != destinationIndex,
          sourceIndex >= 0 && sourceIndex < rows.count,
          destinationIndex >= 0 && destinationIndex <= rows.count else { return }

    let row = rows.remove(at: sourceIndex)
    let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
    rows.insert(row, at: min(adjustedDestination, rows.count))
  }

  // MARK: - Column Operations

  /// Add a new column at the specified index
  func insertColumn(at index: Int, header: String = "", alignment: ColumnAlignment = .left) {
    let insertIndex = min(index, headers.count)

    headers.insert(header, at: insertIndex)
    alignments.insert(alignment, at: insertIndex)

    for i in 0..<rows.count {
      rows[i].insert("", at: insertIndex)
    }
  }

  /// Append a new column at the end
  func appendColumn(header: String = "", alignment: ColumnAlignment = .left) {
    headers.append(header)
    alignments.append(alignment)

    for i in 0..<rows.count {
      rows[i].append("")
    }
  }

  /// Remove a column at the specified index
  func removeColumn(at index: Int) {
    guard index >= 0 && index < headers.count else { return }

    headers.remove(at: index)
    alignments.remove(at: index)

    for i in 0..<rows.count {
      if index < rows[i].count {
        rows[i].remove(at: index)
      }
    }
  }

  // MARK: - Cell Operations

  /// Get cell value
  func cell(row: Int, column: Int) -> String? {
    guard column >= 0 && column < columnCount else { return nil }

    if row == -1 {
      return headers[column]
    } else if row >= 0 && row < rows.count && column < rows[row].count {
      return rows[row][column]
    }

    return nil
  }

  /// Set cell value
  func setCell(row: Int, column: Int, value: String) {
    guard column >= 0 && column < columnCount else { return }

    if row == -1 && column < headers.count {
      headers[column] = value
    } else if row >= 0 && row < rows.count && column < rows[row].count {
      rows[row][column] = value
    }
  }

  // MARK: - Markdown Conversion

  /// Convert the table back to markdown format
  func toMarkdown() -> String {
    var lines: [String] = []

    // Calculate column widths for nice formatting
    var columnWidths = headers.map { $0.count }
    for row in rows {
      for (index, cell) in row.enumerated() where index < columnWidths.count {
        columnWidths[index] = max(columnWidths[index], cell.count)
      }
    }
    // Minimum width of 3 for separator
    columnWidths = columnWidths.map { max($0, 3) }

    // Header row
    let headerCells = headers.enumerated().map { index, header in
      return header.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
    }
    lines.append("| " + headerCells.joined(separator: " | ") + " |")

    // Separator row
    let separatorCells = alignments.enumerated().map { index, alignment -> String in
      let width = columnWidths[index]
      switch alignment {
      case .left:
        return ":" + String(repeating: "-", count: width - 1)
      case .center:
        return ":" + String(repeating: "-", count: width - 2) + ":"
      case .right:
        return String(repeating: "-", count: width - 1) + ":"
      }
    }
    lines.append("| " + separatorCells.joined(separator: " | ") + " |")

    // Data rows
    for row in rows {
      let paddedCells = row.enumerated().map { index, cell -> String in
        if index < columnWidths.count {
          return cell.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
        }
        return cell
      }
      lines.append("| " + paddedCells.joined(separator: " | ") + " |")
    }

    return lines.joined(separator: "\n")
  }
}
