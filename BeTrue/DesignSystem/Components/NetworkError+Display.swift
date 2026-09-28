import Foundation

/// How each failure reads on screen, and whether trying again can help.
extension NetworkError {
    var systemImage: String {
        switch self {
        case .offline: return "wifi.slash"
        case .unauthorized: return "key"
        case .rateLimited: return "hourglass"
        case .server, .invalidResponse: return "exclamationmark.triangle"
        }
    }

    var title: String {
        switch self {
        case .offline: return String(localized: "You're offline")
        case .unauthorized: return String(localized: "Add your API key")
        case .rateLimited: return String(localized: "Taking a short break")
        case .server, .invalidResponse: return String(localized: "Something went wrong")
        }
    }

    var detail: String {
        switch self {
        case .offline:
            return String(localized:
                "What you've already seen stays on this iPhone. New items load when you're back online.")
        case .unauthorized:
            return String(localized:
                "Pexels rejected the API key. Put a valid key in BeTrue/App/Secrets.plist and build again.")
        case .rateLimited:
            return String(localized: "The hourly request limit is used up. Try again in a little while.")
        case .server, .invalidResponse:
            return String(localized: "Pexels didn't answer as expected. Try again.")
        }
    }

    var shortMessage: String {
        switch self {
        case .offline: return String(localized: "You're offline.")
        case .unauthorized: return String(localized: "The API key was rejected.")
        case .rateLimited: return String(localized: "Hourly limit reached.")
        case .server, .invalidResponse: return String(localized: "Couldn't load more.")
        }
    }

    var canRetry: Bool { self != .unauthorized }
}
