//
//  FuzzySearch.swift
//  Pine
//
//  Created by Claude on 2024.
//  Copyright © 2024 Pine. All rights reserved.
//

import Foundation

/// Fuzzy search utility for filtering commands
struct FuzzySearch {

  /// Result of a fuzzy match
  struct MatchResult {
    let matches: Bool
    let score: Int
    let matchedRanges: [Range<String.Index>]

    static let noMatch = MatchResult(matches: false, score: 0, matchedRanges: [])
  }

  /// Perform fuzzy matching of query against text
  /// - Parameters:
  ///   - query: The search query
  ///   - text: The text to search in
  /// - Returns: MatchResult with score and matched ranges
  static func match(query: String, in text: String) -> MatchResult {
    guard !query.isEmpty else {
      return MatchResult(matches: true, score: 0, matchedRanges: [])
    }

    let queryLower = query.lowercased()
    let textLower = text.lowercased()

    // Check for exact substring match first (highest score)
    if let range = textLower.range(of: queryLower) {
      let score = 100 + (text.count - query.count)
      return MatchResult(matches: true, score: score, matchedRanges: [range])
    }

    // Check for prefix match (high score)
    if textLower.hasPrefix(queryLower) {
      return MatchResult(matches: true, score: 90, matchedRanges: [text.startIndex..<text.index(text.startIndex, offsetBy: query.count)])
    }

    // Fuzzy character-by-character matching
    var matchedRanges: [Range<String.Index>] = []
    var queryIndex = queryLower.startIndex
    var textIndex = textLower.startIndex
    var score = 0
    var consecutiveMatches = 0
    var lastMatchIndex: String.Index?

    while queryIndex < queryLower.endIndex && textIndex < textLower.endIndex {
      if queryLower[queryIndex] == textLower[textIndex] {
        let startIndex = text.index(text.startIndex, offsetBy: textLower.distance(from: textLower.startIndex, to: textIndex))
        let endIndex = text.index(after: startIndex)
        matchedRanges.append(startIndex..<endIndex)

        // Bonus for consecutive matches
        if let last = lastMatchIndex, textLower.distance(from: last, to: textIndex) == 1 {
          consecutiveMatches += 1
          score += 5 * consecutiveMatches
        } else {
          consecutiveMatches = 1
        }

        // Bonus for matching at word boundaries
        if textIndex == textLower.startIndex || !textLower[textLower.index(before: textIndex)].isLetter {
          score += 10
        }

        lastMatchIndex = textIndex
        queryIndex = queryLower.index(after: queryIndex)
        score += 1
      }
      textIndex = textLower.index(after: textIndex)
    }

    // Check if all query characters were matched
    if queryIndex == queryLower.endIndex {
      return MatchResult(matches: true, score: score, matchedRanges: matchedRanges)
    }

    return .noMatch
  }

  /// Filter and sort commands by fuzzy matching
  /// - Parameters:
  ///   - commands: Array of commands to filter
  ///   - query: Search query
  /// - Returns: Filtered and sorted array of commands with their scores
  static func filter(commands: [Command], by query: String) -> [(command: Command, score: Int)] {
    guard !query.isEmpty else {
      return commands.map { ($0, 0) }
    }

    return commands
      .compactMap { command -> (command: Command, score: Int)? in
        let titleMatch = match(query: query, in: command.title)
        let categoryMatch = match(query: query, in: command.category.displayName)

        if titleMatch.matches {
          return (command, titleMatch.score)
        } else if categoryMatch.matches {
          return (command, categoryMatch.score / 2)  // Lower priority for category matches
        }
        return nil
      }
      .sorted { $0.score > $1.score }
  }
}
