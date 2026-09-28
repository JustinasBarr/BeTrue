import CryptoKit
import Foundation
import os

/// Downloaded files within a size budget; a write that goes over it deletes the files used longest ago.
/// Writes, marks and trims run in order on one background queue; reads run on the caller's thread.
nonisolated final class DiskCache: Sendable {
    private struct Entry {
        let file: URL
        let size: Int
        let usedAt: Date
    }

    private let directory: URL
    private let budgetBytes: Int
    private let trimTargetBytes: Int
    private let queue = DispatchQueue(label: String(describing: DiskCache.self), qos: .utility)
    /// The folder's size at the last trim plus every write since, so writes do not read the whole folder.
    /// Nil until the first write measures it.
    private let knownSize = OSAllocatedUnfairLock<Int?>(initialState: nil)

    /// The system may empty the Caches folder when the device runs low on space.
    /// `trimTargetBytes` sits below the budget, so a trim is not needed after every new file.
    init(folderName: String, budgetBytes: Int, trimTargetBytes: Int) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent(folderName, isDirectory: true)
        self.budgetBytes = budgetBytes
        self.trimTargetBytes = trimTargetBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Reads synchronously, so call it off the main thread.
    func data(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard let data = try? Data(contentsOf: file) else { return nil }
        touch(file)
        return data
    }

    func contains(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: url).path)
    }

    /// Writes in the background; a later read of `url` finds the file once the write is done.
    func store(_ data: Data, for url: URL) {
        let file = fileURL(for: url)
        queue.async { [self] in
            guard (try? data.write(to: file, options: .atomic)) != nil else { return }
            let needsTrim = knownSize.withLock { size in
                guard let known = size else { return true }
                size = known + data.count
                return known + data.count > budgetBytes
            }
            if needsTrim { deleteLeastRecentlyUsed() }
        }
    }

    /// Marks the file of `url` as just used, so the next trim keeps it.
    func markUsed(_ url: URL) {
        touch(fileURL(for: url))
    }

    func remove(_ url: URL) {
        let file = fileURL(for: url)
        queue.async { try? FileManager.default.removeItem(at: file) }
    }

    private func touch(_ file: URL) {
        queue.async {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        }
    }

    private func deleteLeastRecentlyUsed() {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                       includingPropertiesForKeys: Array(keys))
        else { return }
        var entries = files.compactMap { file -> Entry? in
            guard let values = try? file.resourceValues(forKeys: keys) else { return nil }
            return Entry(file: file,
                         size: values.totalFileAllocatedSize ?? 0,
                         usedAt: values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        if total > budgetBytes {
            entries.sort { $0.usedAt < $1.usedAt }
            for entry in entries {
                guard total > trimTargetBytes else { break }
                guard (try? FileManager.default.removeItem(at: entry.file)) != nil else { continue }
                total -= entry.size
            }
        }
        let measured = total
        knownSize.withLock { $0 = measured }
    }

    /// Named by a hash of the URL: the same URL always finds the same file, and any URL makes a valid name.
    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name, isDirectory: false)
    }
}
