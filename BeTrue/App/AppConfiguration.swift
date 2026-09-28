import Foundation

/// Settings read at launch. The API key comes from the git-ignored `Secrets.plist` or the environment.
struct AppConfiguration: Sendable {
    private enum Constants {
        static let apiBaseURL = URL(string: "https://api.pexels.com/")!
        static let environmentKey = "PEXELS_API_KEY"
        static let secretsFileName = "Secrets"
        static let plistKey = "PexelsAPIKey"
        static let placeholderKey = "paste-your-key-here"
    }

    let apiBaseURL: URL
    let apiKey: String?

    static func load(bundle: Bundle = .main,
                     environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        AppConfiguration(apiBaseURL: Constants.apiBaseURL,
                         apiKey: validKey(environment[Constants.environmentKey]) ?? validKey(plistKey(in: bundle)))
    }

    private static func plistKey(in bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: Constants.secretsFileName, withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) else { return nil }
        return values[Constants.plistKey] as? String
    }

    /// Ignores empty values and the placeholder in `Config/Secrets.example.plist`.
    private static func validKey(_ key: String?) -> String? {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty, key != Constants.placeholderKey else { return nil }
        return key
    }
}
