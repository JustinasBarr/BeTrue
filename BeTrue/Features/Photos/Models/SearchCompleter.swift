import Foundation

/// Finishes a search as the user types.
///
/// Pexels has no suggestion service, so completions come from the device: the user's recent searches, a list of
/// popular topics, and the words in the captions of photos already loaded, which name what the collection holds.
nonisolated struct SearchCompleter {
    private enum Constants {
        static let limit = 5
        static let shortestWord = 3
        /// A popular topic ranks as if this many loaded photos mentioned it.
        static let topicWeight = 2
        /// Two neighbouring caption words become one completion once this many captions pair them.
        static let phraseMinimumCount = 2
        static let topics = [
            "abstract", "aerial", "animals", "architecture", "autumn", "baby", "background", "beach", "bicycle",
            "birds", "black and white", "books", "bridge", "business", "cars", "cats", "christmas", "city",
            "clouds", "coffee", "colorful", "concert", "dark", "desert", "dogs", "fashion", "fireworks", "fitness",
            "flowers", "food", "forest", "fruit", "galaxy", "garden", "horses", "interior", "lake", "landscape",
            "leaves", "light", "love", "minimal", "moon", "mountains", "music", "nature", "neon", "night",
            "night city", "ocean", "office", "people", "plants", "portraits", "rain", "river", "road", "sea",
            "sky", "snow", "space", "sport", "spring", "street", "summer", "sunrise", "sunset", "technology",
            "texture", "travel", "trees", "underwater", "water", "waterfall", "wedding", "wildlife", "winter",
            "workspace", "yoga"
        ]
        /// Caption words that describe the picture's grammar or the photo itself, not a subject worth searching.
        static let stopWords: Set<String> = [
            "and", "the", "with", "from", "for", "near", "over", "under", "into", "onto", "during", "while",
            "through", "against", "beside", "behind", "front", "next", "top", "side", "its", "his", "her", "their",
            "this", "that", "some", "two", "three", "four", "who", "are", "has", "was", "been", "being",
            "photo", "photos", "photography", "picture", "image", "images", "stock", "free", "closeup", "close",
            "view", "shot", "wearing", "holding", "standing", "sitting", "looking", "lying", "using"
        ]
    }

    private struct Term {
        let text: String
        let key: String
    }

    /// Caption terms and popular topics, the ones more photos mention first, then shorter ones.
    private let terms: [Term]

    init(photos: some Sequence<Photo> = []) {
        var counts = Self.captionTerms(of: photos)
        for topic in Constants.topics {
            counts[topic, default: 0] += Constants.topicWeight
        }
        terms = counts
            .sorted { (-$0.value, $0.key.count, $0.key) < (-$1.value, $1.key.count, $1.key) }
            .map { Term(text: $0.key, key: Self.key($0.key)) }
    }

    /// Up to five ways to finish `query`, best first: recent searches, then terms that start with it, then terms
    /// with a later word that does. The query itself is never offered back.
    func completions(for query: String, recentSearches: [String]) -> [String] {
        let needle = Self.key(query)
        guard !needle.isEmpty else { return [] }
        let wordStart = " " + needle
        let recents = recentSearches.map { Term(text: $0, key: Self.key($0)) }
            .filter { $0.key.hasPrefix(needle) || $0.key.contains(wordStart) }
        let prefixed = terms.filter { $0.key.hasPrefix(needle) }
        let wordMatched = terms.filter { !$0.key.hasPrefix(needle) && $0.key.contains(wordStart) }
        var seen: Set<String> = [needle]
        var completions: [String] = []
        for term in recents + prefixed + wordMatched where seen.insert(term.key).inserted {
            completions.append(term.text)
            if completions.count == Constants.limit { break }
        }
        return completions
    }

    /// Where `query` sits in `completion`, for showing the typed part apart from the rest.
    static func matchedRange(of query: String, in completion: String) -> Range<String.Index>? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        var searchStart = completion.startIndex
        while let range = completion.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive],
                                           range: searchStart..<completion.endIndex) {
            let isWordStart = range.lowerBound == completion.startIndex
                || completion[completion.index(before: range.lowerBound)] == " "
            if isWordStart {
                return range
            }
            searchStart = range.upperBound
        }
        return nil
    }

    /// Lowercased, without accents, with single spaces, so "  Café " and "cafe" are the same term.
    private static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Each caption counts once per word, so a caption that repeats a word does not outweigh two photos.
    /// The photographer's name is skipped, since a caption without alt text is "Photo by" that name.
    private static func captionTerms(of photos: some Sequence<Photo>) -> [String: Int] {
        var words: [String: Int] = [:]
        var phrases: [String: Int] = [:]
        for photo in photos {
            let names = Set(tokens(of: photo.photographer))
            var photoWords: Set<String> = []
            var photoPhrases: Set<String> = []
            var previous: String?
            for token in tokens(of: photo.caption) {
                guard token.count >= Constants.shortestWord, !Constants.stopWords.contains(token),
                      !names.contains(token) else {
                    previous = nil
                    continue
                }
                photoWords.insert(token)
                if let previous {
                    photoPhrases.insert("\(previous) \(token)")
                }
                previous = token
            }
            photoWords.forEach { words[$0, default: 0] += 1 }
            photoPhrases.forEach { phrases[$0, default: 0] += 1 }
        }
        for (phrase, count) in phrases where count >= Constants.phraseMinimumCount {
            words[phrase] = count
        }
        return words
    }

    private static func tokens(of text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }
}
