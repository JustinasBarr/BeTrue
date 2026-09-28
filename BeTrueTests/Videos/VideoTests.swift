import Foundation
import Testing
@testable import BeTrue

struct VideoTests {
    /// One entry of `v1/videos/popular` as the API sends it, extra fields included.
    private let apiVideo = """
    {
      "id": 3571264,
      "width": 3840,
      "height": 2160,
      "duration": 33,
      "full_res": null,
      "tags": [],
      "url": "https://www.pexels.com/video/waves-crashing-on-rocks-3571264/",
      "image": "https://images.pexels.com/videos/3571264/free-video-3571264.jpg?fit=crop&h=630&w=1200",
      "avg_color": null,
      "user": { "id": 1583460, "name": "Ana Lima", "url": "https://www.pexels.com/@ana-lima-1583460" },
      "video_files": [
        { "id": 9328, "quality": "uhd", "file_type": "video/mp4", "width": 3840, "height": 2160, "fps": 29.97,
          "link": "https://videos.pexels.com/video-files/3571264/3571264-uhd_3840_2160_30fps.mp4", "size": 58213457 },
        { "id": 9329, "quality": "sd", "file_type": "video/mp4", "width": 640, "height": 360, "fps": 29.97,
          "link": "https://videos.pexels.com/video-files/3571264/3571264-sd_640_360_30fps.mp4", "size": 3152014 },
        { "id": 9330, "quality": "hd", "file_type": "video/mp4", "width": 1280, "height": 720, "fps": 29.97,
          "link": "https://videos.pexels.com/video-files/3571264/3571264-hd_1280_720_30fps.mp4", "size": 9731275 },
        { "id": 9331, "quality": "hd", "file_type": "video/mp4", "width": 1920, "height": 1080, "fps": 29.97,
          "link": "https://videos.pexels.com/video-files/3571264/3571264-hd_1920_1080_30fps.mp4", "size": 19304571 },
        { "id": 9332, "quality": null, "file_type": "video/mp4", "width": null, "height": null, "fps": null,
          "link": "https://videos.pexels.com/video-files/3571264/3571264-hls.m3u8", "size": null }
      ],
      "video_pictures": [
        { "id": 1, "nr": 0, "picture": "https://images.pexels.com/videos/3571264/pictures/preview-0.jpg" }
      ]
    }
    """

    // MARK: Decoding

    @Test func decodesAnAPIVideo() throws {
        let video = try JSONDecoder().decode(Video.self, from: Data(apiVideo.utf8))

        #expect(video.id == 3571264)
        #expect(video.width == 3840)
        #expect(video.height == 2160)
        #expect(video.durationSeconds == 33)
        #expect(video.pageURL.absoluteString == "https://www.pexels.com/video/waves-crashing-on-rocks-3571264/")
        #expect(video.user.name == "Ana Lima")
        #expect(video.user.url?.absoluteString == "https://www.pexels.com/@ana-lima-1583460")
        #expect(video.playbackURL.absoluteString
            == "https://videos.pexels.com/video-files/3571264/3571264-hd_1280_720_30fps.mp4")
        #expect(video.caption == "Waves crashing on rocks")
        #expect(video.aspectRatio == 3840.0 / 2160.0)
    }

    @Test func thumbnailDropsTheProviderCropAndAsksForTheWidth() throws {
        let video = try JSONDecoder().decode(Video.self, from: Data(apiVideo.utf8))

        #expect(video.thumbnailURL(pixelWidth: 640).absoluteString
            == "https://images.pexels.com/videos/3571264/free-video-3571264.jpg?auto=compress&cs=tinysrgb&w=640")
    }

    @Test func missingSizeDurationAndUserDecodeLeniently() throws {
        var json = VideoFixtures.video()
        json["width"] = nil
        json["height"] = 0
        json["duration"] = -3
        json["user"] = nil
        let video = try VideoFixtures.decodeVideo(json)

        #expect(video.aspectRatio == 1)
        #expect(video.durationSeconds == 0)
        #expect(video.user.name.isEmpty)
        #expect(video.user.url == nil)
    }

    // MARK: Caption and text

    @Test func captionComesFromThePageSlug() throws {
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(id: 42, slug: "aerial-view-of-a-city-at-night"))

        #expect(video.caption == "Aerial view of a city at night")
    }

    @Test func captionFallsBackToTheAuthorWhenTheSlugHasNoWords() throws {
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(slug: nil, userName: "Ana Lima"))
        let anonymous = try VideoFixtures.decodeVideo(VideoFixtures.video(slug: nil, userName: ""))

        #expect(video.caption == "Video by Ana Lima")
        #expect(anonymous.caption == "Video")
    }

    @Test(arguments: [(14, "0:14"), (0, "0:00"), (75, "1:15"), (3725, "1:02:05")])
    func durationText(seconds: Int, expected: String) throws {
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(durationSeconds: seconds))

        #expect(video.durationText == expected)
    }

    @Test func spokenDescriptionNamesCaptionLengthAndAuthor() throws {
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(durationSeconds: 14))
        let short = try VideoFixtures.decodeVideo(VideoFixtures.video(durationSeconds: 1, userName: ""))

        #expect(video.spokenDescription == "Waves crashing on rocks, video, 14 seconds by Ana Lima")
        #expect(short.spokenDescription == "Waves crashing on rocks, video, 1 second")
    }

    // MARK: Playback file

    @Test func playsTheMP4ClosestTo1280() throws {
        let video = try decodeVideo(fileWidths: [3840, 640, 1920, 1280, 2560, nil])

        #expect(video.playbackURL.absoluteString == VideoFixtures.link(width: 1280))
    }

    @Test func tieGoesToTheLargerFile() throws {
        let video = try decodeVideo(fileWidths: [640, 1920])

        #expect(video.playbackURL.absoluteString == VideoFixtures.link(width: 1920))
    }

    @Test func onlyLargeFilesPlayTheSmallest() throws {
        let video = try decodeVideo(fileWidths: [nil, 3840, 2560])

        #expect(video.playbackURL.absoluteString == VideoFixtures.link(width: 2560))
    }

    @Test func withoutAnMP4TheFirstFilePlays() throws {
        let files = [VideoFixtures.file(width: 1280, fileType: "video/quicktime"),
                     VideoFixtures.file(width: 640, fileType: "video/webm")]
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(files: files))

        #expect(video.playbackURL.absoluteString == VideoFixtures.link(width: 1280))
    }

    @Test func malformedFilesAreSkipped() throws {
        let files: [[String: Any]] = [["quality": "hd", "width": 1280], VideoFixtures.file(width: 640)]
        let video = try VideoFixtures.decodeVideo(VideoFixtures.video(files: files))

        #expect(video.playbackURL.absoluteString == VideoFixtures.link(width: 640))
    }

    @Test func aVideoWithNothingToPlayFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try VideoFixtures.decodeVideo(VideoFixtures.video(files: []))
        }
    }

    // MARK: Page

    @Test func pageSkipsVideosThatCannotBeShown() throws {
        var missingID = VideoFixtures.video(id: 2)
        missingID["id"] = nil
        let videos = [VideoFixtures.video(id: 1), missingID, VideoFixtures.video(id: 3, files: []),
                      VideoFixtures.video(id: 4)]
        let data = try VideoFixtures.pageData(page: 2, videos: videos, hasMore: true)
        let page = try JSONDecoder().decode(VideoPage.self, from: data)

        #expect(page.page == 2)
        #expect(page.videos.map(\.id) == [1, 4])
        #expect(page.hasMore)
        #expect(page.savedAt == nil)
    }

    @Test func lastPageHasNoMore() throws {
        let data = try VideoFixtures.pageData(videos: [VideoFixtures.video()], hasMore: false)
        let page = try JSONDecoder().decode(VideoPage.self, from: data)

        #expect(!page.hasMore)
    }

    @Test func emptyPageBodyDecodesToNothing() throws {
        let page = try JSONDecoder().decode(VideoPage.self, from: Data("{}".utf8))

        #expect(page.page == 1)
        #expect(page.videos.isEmpty)
        #expect(!page.hasMore)
    }

    // MARK: Viewer

    @MainActor
    @Test func viewerItemCarriesThePlaybackFileAndCredit() throws {
        let video = try JSONDecoder().decode(Video.self, from: Data(apiVideo.utf8))
        let item = ViewerItem(video: video)

        #expect(item.id == "video-3571264")
        #expect(item.videoURL == video.playbackURL)
        #expect(item.title == "Waves crashing on rocks")
        #expect(item.creditName == "Ana Lima")
        #expect(item.previewURL == video.thumbnailURL(pixelWidth: Photo.gridPixelWidth))
        #expect(item.fullImageURL == video.thumbnailURL(pixelWidth: 1600))
    }

    private func decodeVideo(fileWidths: [Int?]) throws -> Video {
        try VideoFixtures.decodeVideo(VideoFixtures.video(files: fileWidths.map { VideoFixtures.file(width: $0) }))
    }
}
