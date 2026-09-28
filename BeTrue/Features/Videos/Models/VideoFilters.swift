import Foundation

/// Popular video filters; nil means any.
nonisolated struct VideoFilters: Hashable, Sendable {
    /// Minimum pixels, asked on both sides so portrait and landscape videos both match.
    nonisolated enum Quality: Int, CaseIterable, Sendable {
        case highDefinition = 720
        case fullHighDefinition = 1080
        case ultraHighDefinition = 2160
    }

    nonisolated enum Length: CaseIterable, Sendable {
        case short
        case medium
        case long

        var seconds: (min: Int?, max: Int?) {
            switch self {
            case .short: (nil, Constants.shortLimit)
            case .medium: (Constants.shortLimit, Constants.longStart)
            case .long: (Constants.longStart, nil)
            }
        }
    }

    private enum Constants {
        /// Seconds: short videos end here and medium ones start.
        static let shortLimit = 15
        /// Seconds: medium videos end here and long ones start.
        static let longStart = 60
    }

    private enum Parameter {
        static let minWidth = "min_width"
        static let minHeight = "min_height"
        static let minDuration = "min_duration"
        static let maxDuration = "max_duration"
    }

    var quality: Quality?
    var length: Length?

    var isEmpty: Bool { self == VideoFilters() }

    /// A fixed order, so equal filters share one offline copy.
    var queryItems: [URLQueryItem] {
        let pairs: [(String, Int?)] = [(Parameter.minWidth, quality?.rawValue),
                                       (Parameter.minHeight, quality?.rawValue),
                                       (Parameter.minDuration, length?.seconds.min),
                                       (Parameter.maxDuration, length?.seconds.max)]
        return pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: String($0)) } }
    }
}
