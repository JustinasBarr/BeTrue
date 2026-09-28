import Foundation
import Testing
@testable import BeTrue

private final class TestBundleToken {}

@MainActor
@Suite struct AppConfigurationTests {
    private enum Constants {
        static let environmentKey = "PEXELS_API_KEY"
        static let plistKey = "PexelsAPIKey"
        static let placeholderKey = "paste-your-key-here"
    }

    /// The test bundle has no `Secrets.plist`, so only the environment can supply a key.
    private let bundleWithoutSecrets = Bundle(for: TestBundleToken.self)

    @Test func usesTheKeyFromTheEnvironment() {
        let configuration = AppConfiguration.load(bundle: bundleWithoutSecrets,
                                                  environment: [Constants.environmentKey: "env-key"])

        #expect(configuration.apiKey == "env-key")
        #expect(configuration.apiBaseURL.absoluteString == "https://api.pexels.com/")
    }

    @Test func trimsTheKey() {
        let configuration = AppConfiguration.load(bundle: bundleWithoutSecrets,
                                                  environment: [Constants.environmentKey: "  env-key\n"])

        #expect(configuration.apiKey == "env-key")
    }

    @Test(arguments: ["", "   ", Constants.placeholderKey])
    func ignoresEmptyAndPlaceholderKeys(key: String) {
        let configuration = AppConfiguration.load(bundle: bundleWithoutSecrets,
                                                  environment: [Constants.environmentKey: key])

        #expect(configuration.apiKey == nil)
    }

    @Test func hasNoKeyWithoutEnvironmentOrSecrets() {
        #expect(AppConfiguration.load(bundle: bundleWithoutSecrets, environment: [:]).apiKey == nil)
    }

    @Test func environmentWinsOverSecretsFile() throws {
        let bundle = try makeBundle(secretsKey: "plist-key")

        let configuration = AppConfiguration.load(bundle: bundle, environment: [Constants.environmentKey: "env-key"])

        #expect(configuration.apiKey == "env-key")
    }

    @Test func placeholderInTheEnvironmentFallsBackToSecretsFile() throws {
        let bundle = try makeBundle(secretsKey: "plist-key")

        let configuration = AppConfiguration.load(bundle: bundle,
                                                  environment: [Constants.environmentKey: Constants.placeholderKey])

        #expect(configuration.apiKey == "plist-key")
    }

    @Test func placeholderInSecretsFileIsIgnored() throws {
        let bundle = try makeBundle(secretsKey: Constants.placeholderKey)

        #expect(AppConfiguration.load(bundle: bundle, environment: [:]).apiKey == nil)
    }

    /// A throwaway bundle directory holding only a `Secrets.plist`, unique per test so `Bundle` never caches it.
    private func makeBundle(secretsKey: String) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: [Constants.plistKey: secretsKey],
                                                       format: .xml, options: 0)
        try plist.write(to: directory.appendingPathComponent("Secrets.plist"))
        return try #require(Bundle(url: directory))
    }
}
