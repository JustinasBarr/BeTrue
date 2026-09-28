import ImageIO
import UIKit

/// Loads remote images decoded at the size they are shown.
nonisolated protocol ImageLoading: Sendable {
    /// An already decoded image, read synchronously so a reused cell never flashes its placeholder.
    func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage?
    /// The most recently decoded copy of `url` at any size, so a viewer can start from the grid's copy.
    func cachedImage(for url: URL) -> UIImage?
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage?
    /// Saves `urls` on disk for offline use; downloads only on Wi-Fi without Low Data Mode.
    func keepOffline(_ urls: [URL]) async
}

/// Memory, then disk, then network. Downsamples off the main thread: a 4000 px photo costs 1.5 MB, not 96 MB.
nonisolated final class ImageLoader: ImageLoading, @unchecked Sendable {
    private enum Constants {
        static let megabyte = 1024 * 1024
        static let memoryLimitBytes = 96 * megabyte
        /// About 1,700 grid pictures, or 250 full-screen photos.
        static let diskBudgetBytes = 200 * megabyte
        static let diskTrimTargetBytes = 160 * megabyte
        static let diskCacheFolder = "ImageFiles"
        /// Where earlier builds kept downloads, in a URLCache that nothing reads any more.
        static let legacyDiskCacheFolder = "Images"
        static let connectionsPerHost = 6
        /// Saving for later leaves most of the connection to the tiles on screen.
        static let keepingConnectionsPerHost = 2
        static let successStatusCodes = 200..<300
    }

    private let memoryCache = NSCache<NSString, UIImage>()
    /// The cache key of each URL's latest decode, for lookups that do not know the decoded size.
    private let latestKeys = NSCache<NSString, NSString>()
    private let session: URLSession
    /// Only on Wi-Fi without Low Data Mode: saving pictures for later must not spend the user's data plan.
    private let keepingSession: URLSession
    private let disk = DiskCache(folderName: Constants.diskCacheFolder,
                                 budgetBytes: Constants.diskBudgetBytes,
                                 trimTargetBytes: Constants.diskTrimTargetBytes)
    private let inFlight = InFlightImageTasks()

    init() {
        memoryCache.totalCostLimit = Constants.memoryLimitBytes
        session = URLSession(configuration: Self.configuration(connectionsPerHost: Constants.connectionsPerHost))
        let keeping = Self.configuration(connectionsPerHost: Constants.keepingConnectionsPerHost)
        keeping.allowsExpensiveNetworkAccess = false
        keeping.allowsConstrainedNetworkAccess = false
        keepingSession = URLSession(configuration: keeping)
        Self.removeLegacyDiskCache()
    }

    func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memoryCache.object(forKey: Self.cacheKey(url, maxPixelSize) as NSString)
    }

    func cachedImage(for url: URL) -> UIImage? {
        guard let key = latestKeys.object(forKey: url.absoluteString as NSString) else { return nil }
        return memoryCache.object(forKey: key)
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        if let image = cachedImage(for: url, maxPixelSize: maxPixelSize) { return image }
        let key = Self.cacheKey(url, maxPixelSize)
        let task = await inFlight.task(for: key) { [session, disk] in
            if let image = await Self.savedImage(for: url, in: disk, maxPixelSize: maxPixelSize) { return image }
            guard let data = await Self.download(url, with: session),
                  let image = await Self.downsample(data, maxPixelSize: maxPixelSize) else { return nil }
            // Only a file that decoded is saved, so an error page never stands in for a picture.
            disk.store(data, for: url)
            return image
        }
        let image = await task.value
        await inFlight.remove(key)
        if let image {
            memoryCache.setObject(image, forKey: key as NSString, cost: Self.memoryCost(of: image))
            latestKeys.setObject(key as NSString, forKey: url.absoluteString as NSString)
        }
        return image
    }

    func keepOffline(_ urls: [URL]) async {
        await Self.keep(urls, in: disk, downloadingWith: keepingSession)
    }

    /// For a memory warning. Downloaded files stay on disk.
    func removeDecodedImages() {
        memoryCache.removeAllObjects()
    }

    /// Nothing is decoded: the files only need to be on disk.
    @concurrent
    private static func keep(_ urls: [URL], in disk: DiskCache, downloadingWith session: URLSession) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls where !Task.isCancelled {
                if disk.contains(url) {
                    disk.markUsed(url)
                } else {
                    group.addTask {
                        guard let data = await Self.download(url, with: session), Self.isImage(data) else { return }
                        disk.store(data, for: url)
                    }
                }
            }
        }
    }

    /// A saved file that no longer decodes is deleted, so the image downloads again.
    @concurrent
    private static func savedImage(for url: URL, in disk: DiskCache, maxPixelSize: CGFloat) async -> UIImage? {
        guard let data = disk.data(for: url) else { return nil }
        guard let image = await downsample(data, maxPixelSize: maxPixelSize) else {
            disk.remove(url)
            return nil
        }
        return image
    }

    /// Nil on failure or a non-2xx answer, such as an error page.
    private static func download(_ url: URL, with session: URLSession) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              Constants.successStatusCodes.contains(statusCode) else { return nil }
        return data
    }

    @concurrent
    private static func downsample(_ data: Data, maxPixelSize: CGFloat) async -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }

    /// Reads only the header, to tell a picture from an error page without decoding it.
    private static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetType(source) != nil
    }

    private static func configuration(connectionsPerHost: Int) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        // `DiskCache` keeps downloads instead, so it can choose which pictures to drop.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = connectionsPerHost
        #if DEBUG
        configuration.simulateOfflineIfRequested()
        #endif
        return configuration
    }

    private static func removeLegacyDiskCache() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent(Constants.legacyDiskCacheFolder, isDirectory: true)
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private static func cacheKey(_ url: URL, _ maxPixelSize: CGFloat) -> String {
        "\(Int(maxPixelSize))|\(url.absoluteString)"
    }

    private static func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

private actor InFlightImageTasks {
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func task(for key: String, start: @escaping @Sendable () async -> UIImage?) -> Task<UIImage?, Never> {
        if let task = tasks[key] { return task }
        let task = Task { await start() }
        tasks[key] = task
        return task
    }

    func remove(_ key: String) {
        tasks[key] = nil
    }
}
