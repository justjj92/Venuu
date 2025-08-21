import Foundation

/// Lightweight, on-device summarizer for venue review comments.
/// No network calls; returns a short keyword-style summary.
final class AISummaryEngine {
    static let shared = AISummaryEngine()
    private init() {}

    /// Build a brief sentence like:
    /// "What people mentioned most: parking, staff, bbq."
    func summarize(venueReviews: [CloudStore.VenueReviewRead]) async throws -> String? {
        // Collect non-empty comments
        let comments = venueReviews
            .compactMap { $0.comment?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !comments.isEmpty else { return nil }

        // Tokenize & count
        var freq: [String: Int] = [:]
        for c in comments {
            for token in tokenize(c) {
                freq[token, default: 0] += 1
            }
        }

        // Top 3 frequent terms
        let top = freq
            .sorted { (a, b) in
                if a.value != b.value { return a.value > b.value }
                return a.key < b.key
            }
            .prefix(3)
            .map { $0.key }

        guard !top.isEmpty else { return nil }
        return "What people mentioned most: " + top.joined(separator: ", ") + "."
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let cleaned = lowered.replacingOccurrences(of: "[^a-z0-9 ]",
                                                   with: " ",
                                                   options: .regularExpression)
        let raw = cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }

        // Keep it simple—drop very common stopwords but keep adjectives like
        // "great", "amazing", etc. so they can surface in the summary.
        let stop: Set<String> = [
            "the","a","an","and","or","but","with","for","to","from","of","at","on","in","into",
            "this","that","these","those","there","their","they","them","it","its","is","are",
            "was","were","be","been","being","i","we","you","he","she","my","our","your","his","her",
            "as","if","by","so","than","then","too","very","really","just","more","most","less","least",
            "not","no","yes","up","down","out","over","under"
        ]

        return raw
            .filter { $0.count >= 3 }
            .filter { !stop.contains($0) }
    }
}
