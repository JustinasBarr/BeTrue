import Foundation
@testable import BeTrue

/// API payloads as string literals, so tests never read the network or a bundle file.
enum Fixtures {
    static let defaultPageSize = 40

    /// A curated page shaped like the real API response: two photos, one with alt text and one without.
    static let curatedPageJSON = """
    {
      "page": 1,
      "per_page": 2,
      "photos": [
        {
          "id": 2014422,
          "width": 3024,
          "height": 4032,
          "url": "https://www.pexels.com/photo/brown-rocks-during-golden-hour-2014422/",
          "photographer": "Joey Farina",
          "photographer_url": "https://www.pexels.com/@joey",
          "photographer_id": 680589,
          "avg_color": "#978E82",
          "src": {
            "original": "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg",
            "small": "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg?auto=compress&h=130"
          },
          "liked": false,
          "alt": "Brown Rocks During Golden Hour"
        },
        {
          "id": 1181244,
          "width": 6000,
          "height": 4000,
          "url": "https://www.pexels.com/photo/woman-in-white-long-sleeved-top-1181244/",
          "photographer": "Christina Morillo",
          "photographer_url": "https://www.pexels.com/@divinetechygirl",
          "photographer_id": 299257,
          "avg_color": "#62645F",
          "src": {
            "original": "https://images.pexels.com/photos/1181244/pexels-photo-1181244.jpeg"
          },
          "liked": false,
          "alt": ""
        }
      ],
      "total_results": 8000,
      "next_page": "https://api.pexels.com/v1/curated/?page=2&per_page=2"
    }
    """

    /// One photo. `url` defaults to a page whose slug is just "photo" and the id.
    static func photoJSON(id: Int,
                          alt: String? = "A photo",
                          url: String? = nil,
                          photographer: String = "Joey Farina",
                          width: Int = 3000,
                          height: Int = 2000) -> String {
        let altField = alt.map { "\"alt\": \"\($0)\"," } ?? ""
        return """
        {
          "id": \(id),
          "width": \(width),
          "height": \(height),
          "url": "\(url ?? "https://www.pexels.com/photo/photo-\(id)/")",
          "photographer": "\(photographer)",
          "photographer_url": "https://www.pexels.com/@photographer",
          "avg_color": "#978E82",
          \(altField)
          "src": { "original": "https://images.pexels.com/photos/\(id)/pexels-photo-\(id).jpeg" }
        }
        """
    }

    static func pageJSON(ids: [Int], page: Int = 1, hasMore: Bool = true) -> String {
        let nextPage = hasMore ? "\"next_page\": \"https://api.pexels.com/v1/curated/?page=\(page + 1)\"," : ""
        return """
        {
          "page": \(page),
          "per_page": 40,
          \(nextPage)
          "photos": [\(ids.map { photoJSON(id: $0) }.joined(separator: ","))]
        }
        """
    }

    static func photo(id: Int,
                      alt: String? = "A photo",
                      url: String? = nil,
                      photographer: String = "Joey Farina",
                      width: Int = 3000,
                      height: Int = 2000) throws -> Photo {
        let json = photoJSON(id: id, alt: alt, url: url, photographer: photographer, width: width, height: height)
        return try JSONDecoder().decode(Photo.self, from: Data(json.utf8))
    }

    /// Page `page` of an endless feed of `size` photos per page, with ids that never repeat across pages.
    static func feedPage(_ page: Int, size: Int = defaultPageSize) throws -> PhotoPage {
        try self.page(ids: Array((page - 1) * size + 1...page * size), page: page)
    }

    static func page(ids: [Int], page: Int = 1, hasMore: Bool = true) throws -> PhotoPage {
        try JSONDecoder().decode(PhotoPage.self, from: Data(pageJSON(ids: ids, page: page, hasMore: hasMore).utf8))
    }
}
