import Foundation

/// A photo as the API returns it, decoded straight from the response.
nonisolated struct Photo: Decodable, Identifiable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id, width, height, url, photographer, alt, src
        case photographerURL = "photographer_url"
        case averageColor = "avg_color"
    }

    private enum SourceKeys: String, CodingKey {
        case original
    }

    let id: Int
    let width: Int
    let height: Int
    let pageURL: URL
    let photographer: String
    let photographerURL: URL?
    /// Hex colour shown while the image loads.
    let averageColor: String?
    /// A readable description: the provider's alt text, the page URL's slug, or the photographer's name.
    let caption: String

    /// Never zero.
    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    private let originalURL: URL

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        pageURL = try container.decode(URL.self, forKey: .url)
        photographer = try container.decodeIfPresent(String.self, forKey: .photographer) ?? ""
        photographerURL = try? container.decodeIfPresent(URL.self, forKey: .photographerURL)
        averageColor = try container.decodeIfPresent(String.self, forKey: .averageColor)
        originalURL = try container.nestedContainer(keyedBy: SourceKeys.self, forKey: .src)
            .decode(URL.self, forKey: .original)
        let alt = try container.decodeIfPresent(String.self, forKey: .alt)
        caption = Self.caption(alt: alt, pageURL: pageURL, photographer: photographer)
    }

    /// Resized by the CDN so a grid cell never downloads the original.
    func imageURL(pixelWidth: Int) -> URL {
        guard var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) else {
            return originalURL
        }
        components.queryItems = [
            URLQueryItem(name: "auto", value: "compress"),
            URLQueryItem(name: "cs", value: "tinysrgb"),
            URLQueryItem(name: "w", value: String(max(pixelWidth, 1)))
        ]
        return components.url ?? originalURL
    }

    /// Many photos have no alt text; the page URL ends in a readable slug.
    private static func caption(alt: String?, pageURL: URL, photographer: String) -> String {
        if let alt = alt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }
        let words = pageURL.lastPathComponent.split(separator: "-").filter { Int($0) == nil }
        if !words.isEmpty {
            let slug = words.joined(separator: " ")
            return slug.prefix(1).uppercased() + slug.dropFirst()
        }
        return photographer.isEmpty ? "Photo" : "Photo by \(photographer)"
    }
}

/// One page of photos. A photo that fails to decode is skipped instead of failing the page.
nonisolated struct PhotoPage: Decodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case page, photos
        case nextPage = "next_page"
    }

    let page: Int
    let photos: [Photo]
    let hasMore: Bool
    /// Nil when it came from the network just now.
    private(set) var savedAt: Date?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        photos = try container.decodeIfPresent([Lenient<Photo>].self, forKey: .photos)?
            .compactMap(\.value) ?? []
        hasMore = try container.decodeIfPresent(String.self, forKey: .nextPage) != nil
    }

    func markedSaved(at date: Date) -> PhotoPage {
        var page = self
        page.savedAt = date
        return page
    }
}

nonisolated private struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}
