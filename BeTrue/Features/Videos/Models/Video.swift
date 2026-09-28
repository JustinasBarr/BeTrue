import Foundation

nonisolated struct Video: Decodable, Identifiable, Hashable, Sendable {
    private enum Constants {
        /// Sharp on a phone at a fraction of the bandwidth of the 4K files.
        static let preferredPlaybackWidth = 1280
        static let maxPlaybackWidth = 1920
    }

    private enum CodingKeys: String, CodingKey {
        case id, width, height, url, image, duration, user
        case files = "video_files"
    }

    private enum UserKeys: String, CodingKey {
        case name, url
    }

    let id: Int
    let width: Int
    let height: Int
    let pageURL: URL
    let durationSeconds: Int
    let user: User
    let playbackURL: URL
    let caption: String

    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    /// "0:14", or "1:02:05" past an hour.
    var durationText: String {
        let hours = durationSeconds / 3600
        let minutes = durationSeconds / 60 % 60
        let seconds = durationSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    var spokenDescription: String {
        let length = durationSeconds == 1 ? "1 second" : "\(durationSeconds) seconds"
        let byline = user.name.isEmpty ? "" : " by \(user.name)"
        return "\(caption), video, \(length)\(byline)"
    }

    private let thumbnailSourceURL: URL

    nonisolated struct User: Hashable, Sendable {
        let name: String
        let url: URL?
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        pageURL = try container.decode(URL.self, forKey: .url)
        thumbnailSourceURL = try container.decode(URL.self, forKey: .image)
        durationSeconds = max(try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0, 0)
        user = Self.user(in: container)
        let files = try container.decodeIfPresent([Lenient<VideoFile>].self, forKey: .files)?
            .compactMap(\.value) ?? []
        guard let playbackURL = Self.playbackURL(in: files) else {
            throw DecodingError.dataCorruptedError(forKey: .files, in: container,
                                                   debugDescription: "No playable file")
        }
        self.playbackURL = playbackURL
        caption = Self.caption(pageURL: pageURL, author: user.name)
    }

    /// The still-frame URL crops to 1200 x 630; replacing its query keeps the video's own shape.
    func thumbnailURL(pixelWidth: Int) -> URL {
        guard var components = URLComponents(url: thumbnailSourceURL, resolvingAgainstBaseURL: false) else {
            return thumbnailSourceURL
        }
        components.queryItems = [
            URLQueryItem(name: "auto", value: "compress"),
            URLQueryItem(name: "cs", value: "tinysrgb"),
            URLQueryItem(name: "w", value: String(max(pixelWidth, 1)))
        ]
        return components.url ?? thumbnailSourceURL
    }

    /// The MP4 closest to the preferred width under the maximum, else the smallest MP4, else any file.
    private static func playbackURL(in files: [VideoFile]) -> URL? {
        let mp4s = files.filter(\.isMP4)
        let fitting = mp4s.compactMap { file -> (link: URL, width: Int)? in
            guard let width = file.width, width <= Constants.maxPlaybackWidth else { return nil }
            return (file.link, width)
        }
        let closest = fitting.min { lhs, rhs in
            let lhsDistance = abs(lhs.width - Constants.preferredPlaybackWidth)
            let rhsDistance = abs(rhs.width - Constants.preferredPlaybackWidth)
            return lhsDistance == rhsDistance ? lhs.width > rhs.width : lhsDistance < rhsDistance
        }
        if let closest { return closest.link }
        let smallestMP4 = mp4s.min { ($0.width ?? .max) < ($1.width ?? .max) }
        return smallestMP4?.link ?? files.first?.link
    }

    private static func user(in container: KeyedDecodingContainer<CodingKeys>) -> User {
        guard let userContainer = try? container.nestedContainer(keyedBy: UserKeys.self, forKey: .user) else {
            return User(name: "", url: nil)
        }
        return User(name: (try? userContainer.decodeIfPresent(String.self, forKey: .name)) ?? "",
                    url: try? userContainer.decodeIfPresent(URL.self, forKey: .url))
    }

    /// Video pages end in a readable slug.
    private static func caption(pageURL: URL, author: String) -> String {
        let words = pageURL.lastPathComponent.split(separator: "-").filter { Int($0) == nil }
        if !words.isEmpty {
            let slug = words.joined(separator: " ")
            return slug.prefix(1).uppercased() + slug.dropFirst()
        }
        return author.isEmpty ? "Video" : "Video by \(author)"
    }
}

/// A video that fails to decode, or has nothing to play, is skipped instead of failing the page.
nonisolated struct VideoPage: Decodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case page, videos
        case nextPage = "next_page"
    }

    let page: Int
    let videos: [Video]
    let hasMore: Bool
    /// Nil when the page came from the network just now.
    private(set) var savedAt: Date?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        videos = try container.decodeIfPresent([Lenient<Video>].self, forKey: .videos)?
            .compactMap(\.value) ?? []
        hasMore = try container.decodeIfPresent(String.self, forKey: .nextPage) != nil
    }

    func markedSaved(at date: Date) -> VideoPage {
        var page = self
        page.savedAt = date
        return page
    }
}

/// One encoding of a video. Streaming entries come without a size.
nonisolated private struct VideoFile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case link, width
        case fileType = "file_type"
    }

    let link: URL
    let width: Int?
    let fileType: String?

    var isMP4: Bool {
        fileType?.lowercased() == "video/mp4"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        link = try container.decode(URL.self, forKey: .link)
        width = (try? container.decodeIfPresent(Int.self, forKey: .width)).flatMap { $0 > 0 ? $0 : nil }
        fileType = try? container.decodeIfPresent(String.self, forKey: .fileType)
    }
}

nonisolated private struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}
