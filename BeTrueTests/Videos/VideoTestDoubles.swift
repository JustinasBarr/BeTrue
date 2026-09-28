import Foundation
import os
@testable import BeTrue

/// API-shaped JSON for videos, so every test goes through the real decoders.
enum VideoFixtures {
    /// Streaming entries (`width: nil`) come without a size, as in the API.
    static func file(width: Int?, fileType: String = "video/mp4") -> [String: Any] {
        var file: [String: Any] = ["file_type": fileType, "link": link(width: width)]
        if let width {
            file["quality"] = "hd"
            file["width"] = width
            file["height"] = width * 9 / 16
        } else {
            file["quality"] = NSNull()
            file["width"] = NSNull()
            file["height"] = NSNull()
        }
        return file
    }

    static func link(width: Int?) -> String {
        "https://videos.pexels.com/video-files/1/\(width.map(String.init) ?? "stream").mp4"
    }

    /// A nil slug gives a page URL made only of the id, which has no words for a caption.
    static func video(id: Int = 1,
                      slug: String? = "waves-crashing-on-rocks",
                      durationSeconds: Int = 14,
                      userName: String = "Ana Lima",
                      files: [[String: Any]] = [file(width: 1280)]) -> [String: Any] {
        [
            "id": id,
            "width": 1920,
            "height": 1080,
            "url": "https://www.pexels.com/video/\(slug.map { "\($0)-" } ?? "")\(id)/",
            "image": "https://images.pexels.com/videos/\(id)/free-video-\(id).jpg?fit=crop&w=1200&h=630",
            "duration": durationSeconds,
            "user": ["id": 7, "name": userName, "url": "https://www.pexels.com/@ana"],
            "video_files": files
        ]
    }

    static func decodeVideo(_ json: [String: Any]) throws -> Video {
        try JSONDecoder().decode(Video.self, from: JSONSerialization.data(withJSONObject: json))
    }

    static func pageData(page: Int = 1, videos: [[String: Any]], hasMore: Bool) throws -> Data {
        var json: [String: Any] = ["page": page, "per_page": 20, "videos": videos]
        if hasMore {
            json["next_page"] = "https://api.pexels.com/v1/videos/popular/?page=\(page + 1)&per_page=20"
        }
        return try JSONSerialization.data(withJSONObject: json)
    }

    static func page(_ page: Int, ids: ClosedRange<Int>, hasMore: Bool) throws -> VideoPage {
        let data = try pageData(page: page, videos: ids.map { video(id: $0) }, hasMore: hasMore)
        return try JSONDecoder().decode(VideoPage.self, from: data)
    }
}

/// Answers every request with one fixed response and records what was asked. A locked class, not an actor,
/// for the reason given on `VideoTestRepository`.
final class VideoTestNetwork: NetworkService {
    var requests: [NetworkRequest] {
        state.withLock { $0.requests }
    }

    private let state: OSAllocatedUnfairLock<State>

    private struct State {
        var requests: [NetworkRequest] = []
        var response: Result<Data, NetworkError>
    }

    init(response: Result<Data, NetworkError>) {
        state = OSAllocatedUnfairLock(initialState: State(response: response))
    }

    func respond(with response: Result<Data, NetworkError>) {
        state.withLock { $0.response = response }
    }

    func data(for request: NetworkRequest) async throws -> Data {
        try state.withLock { state in
            state.requests.append(request)
            return try state.response.get()
        }
    }
}

/// Keeps values in memory, each saved at `savedAt`. A locked class, not an actor, for the reason given on
/// `VideoTestRepository`.
final class VideoTestStore: LocalStoring {
    let savedAt: Date
    var values: [String: SavedData] {
        saved.withLock { $0 }
    }

    private let saved = OSAllocatedUnfairLock<[String: SavedData]>(initialState: [:])

    init(savedAt: Date) {
        self.savedAt = savedAt
    }

    func savedData(forKey key: String) async -> SavedData? {
        saved.withLock { $0[key] }
    }

    func save(_ data: Data, forKey key: String) async {
        let value = SavedData(data: data, savedAt: savedAt)
        saved.withLock { $0[key] = value }
    }

    /// Every value shares one save time here, so which of the matching values stay is unspecified.
    func removeSavedData(withKeyPrefix prefix: String, keepingNewest count: Int) async {
        saved.withLock { values in
            values.keys.filter { $0.hasPrefix(prefix) }.sorted().dropFirst(count).forEach { values[$0] = nil }
        }
    }
}

/// Pages without a result fail as offline, so a test sets only the pages it expects to load.
///
/// A locked class, not an actor: an actor conforming to this protocol from the test target fails to compile
/// ("'nonisolated' on an actor's synchronous initializer is invalid").
final class VideoTestRepository: VideoRepository {
    var requestedPages: [Int] {
        state.withLock { $0.requestedPages }
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var requestedPages: [Int] = []
        var results: [Int: Result<VideoPage, NetworkError>] = [:]
    }

    func setResult(_ result: Result<VideoPage, NetworkError>, forPage page: Int) {
        state.withLock { $0.results[page] = result }
    }

    func popularVideos(filters: VideoFilters, page: Int) async throws -> VideoPage {
        let result = state.withLock { state in
            state.requestedPages.append(page)
            return state.results[page]
        }
        guard let result else { throw NetworkError.offline }
        return try result.get()
    }

    func searchVideos(matching query: String, page: Int) async throws -> VideoPage {
        throw NetworkError.invalidResponse
    }
}
