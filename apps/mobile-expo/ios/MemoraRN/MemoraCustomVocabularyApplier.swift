import Foundation
import MemoraSharedSchema

/// Applies user vocabulary as literal text substitutions in one pass.
/// A replacement is appended directly to the result, so it never becomes input
/// for a later rule (for example, A→B and B→C turns "AB" into "BC", not "CC").
struct MemoraCustomVocabularyApplier {
  private let rules: [(pattern: String, replacement: String)]

  init(vocabulary: [CustomVocabulary]) {
    rules = vocabulary
      .filter { $0.enabled && !$0.pattern.isEmpty }
      .sorted {
        if $0.pattern.count == $1.pattern.count {
          return $0.createdAt < $1.createdAt
        }
        return $0.pattern.count > $1.pattern.count
      }
      .map { (pattern: $0.pattern, replacement: $0.replacement) }
  }

  func apply(to text: String) -> String {
    guard !rules.isEmpty, !text.isEmpty else { return text }

    var result = ""
    var index = text.startIndex
    while index < text.endIndex {
      if let rule = rules.first(where: { text[index...].hasPrefix($0.pattern) }) {
        result += rule.replacement
        index = text.index(index, offsetBy: rule.pattern.count)
      } else {
        result.append(text[index])
        index = text.index(after: index)
      }
    }
    return result
  }
}
