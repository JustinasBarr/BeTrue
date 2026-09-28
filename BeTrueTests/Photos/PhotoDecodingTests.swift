import Foundation
import Testing
@testable import BeTrue

@Suite struct PhotoDecodingTests {
    @Test func decodesARealCuratedPage() throws {
        let page = try JSONDecoder().decode(PhotoPage.self, from: Data(Fixtures.curatedPageJSON.utf8))
        let photo = try #require(page.photos.first)

        #expect(page.page == 1)
        #expect(page.photos.count == 2)
        #expect(page.hasMore)
        #expect(page.savedAt == nil)
        #expect(photo.id == 2014422)
        #expect(photo.width == 3024)
        #expect(photo.height == 4032)
        #expect(photo.pageURL.absoluteString == "https://www.pexels.com/photo/brown-rocks-during-golden-hour-2014422/")
        #expect(photo.photographer == "Joey Farina")
        #expect(photo.photographerURL?.absoluteString == "https://www.pexels.com/@joey")
        #expect(photo.averageColor == "#978E82")
        #expect(photo.caption == "Brown Rocks During Golden Hour")
    }

    @Test func captionComesFromTheURLSlugWhenAltIsEmpty() throws {
        let photo = try Fixtures.photo(id: 2014422, alt: "",
                                       url: "https://www.pexels.com/photo/brown-rocks-during-golden-hour-2014422/")

        #expect(photo.caption == "Brown rocks during golden hour")
    }

    @Test(arguments: [nil, "   "])
    func captionIgnoresMissingOrBlankAlt(alt: String?) throws {
        let photo = try Fixtures.photo(id: 1, alt: alt, url: "https://www.pexels.com/photo/red-car-1/")

        #expect(photo.caption == "Red car")
    }

    @Test func captionCreditsThePhotographerWhenTheSlugIsOnlyAnID() throws {
        let photo = try Fixtures.photo(id: 2014422, alt: "", url: "https://www.pexels.com/photo/2014422/",
                                       photographer: "Joey Farina")

        #expect(photo.caption == "Photo by Joey Farina")
    }

    @Test func captionFallsBackToPhotoWithoutAPhotographer() throws {
        let photo = try Fixtures.photo(id: 2014422, alt: "", url: "https://www.pexels.com/photo/2014422/",
                                       photographer: "")

        #expect(photo.caption == "Photo")
    }

    @Test func aspectRatioIsWidthOverHeight() throws {
        let photo = try Fixtures.photo(id: 1, width: 3000, height: 2000)

        #expect(photo.aspectRatio == 1.5)
    }

    @Test(arguments: [(0, 2000), (3000, 0), (0, 0)])
    func aspectRatioIsNeverZero(width: Int, height: Int) throws {
        let photo = try Fixtures.photo(id: 1, width: width, height: height)

        #expect(photo.aspectRatio == 1)
    }

    @Test func imageURLAsksTheCDNForTheRequestedWidth() throws {
        let photo = try Fixtures.photo(id: 2014422)

        let url = photo.imageURL(pixelWidth: Photo.gridPixelWidth)

        #expect(url.absoluteString ==
                "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg?auto=compress&cs=tinysrgb&w=640")
    }

    @Test(arguments: [0, -40])
    func imageURLNeverAsksForZeroWidth(pixelWidth: Int) throws {
        let photo = try Fixtures.photo(id: 1)

        let items = URLComponents(url: photo.imageURL(pixelWidth: pixelWidth), resolvingAgainstBaseURL: false)?
            .queryItems

        #expect(items?.first { $0.name == "w" }?.value == "1")
    }

    @Test func pageSkipsAMalformedPhotoAndKeepsTheRest() throws {
        let broken = #"{ "id": "not-a-number", "url": "https://www.pexels.com/photo/x-2/" }"#
        let json = """
        { "page": 3, "photos": [\(Fixtures.photoJSON(id: 1)), \(broken), \(Fixtures.photoJSON(id: 3))] }
        """

        let page = try JSONDecoder().decode(PhotoPage.self, from: Data(json.utf8))

        #expect(page.page == 3)
        #expect(page.photos.map(\.id) == [1, 3])
    }

    @Test func pageWithoutNextPageHasNoMore() throws {
        let page = try Fixtures.page(ids: [1, 2], hasMore: false)

        #expect(!page.hasMore)
    }

    @Test func pageWithNullNextPageHasNoMore() throws {
        let json = #"{ "page": 1, "photos": [], "next_page": null }"#

        let page = try JSONDecoder().decode(PhotoPage.self, from: Data(json.utf8))

        #expect(!page.hasMore)
        #expect(page.photos.isEmpty)
    }

    @Test func markedSavedKeepsThePhotos() throws {
        let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let page = try Fixtures.page(ids: [1, 2]).markedSaved(at: savedAt)

        #expect(page.savedAt == savedAt)
        #expect(page.photos.map(\.id) == [1, 2])
    }
}
