import Foundation
import Testing
@testable import BeTrue

@Suite struct LocalStoreTests {
    @Test func savedDataComesBackWithItsDate() async throws {
        let store = LocalStore(inMemory: true)
        let before = Date()

        await store.save(Data("first".utf8), forKey: "v1/curated?page=1")
        let saved = try #require(await store.savedData(forKey: "v1/curated?page=1"))

        #expect(saved.data == Data("first".utf8))
        #expect(saved.savedAt >= before.addingTimeInterval(-1))
        #expect(saved.savedAt <= Date())
    }

    @Test func savingTheSameKeyAgainReplacesTheValue() async throws {
        let store = LocalStore(inMemory: true)

        await store.save(Data("first".utf8), forKey: "key")
        await store.save(Data("second".utf8), forKey: "key")

        #expect(await store.savedData(forKey: "key")?.data == Data("second".utf8))
    }

    @Test func unknownKeyHasNoData() async {
        let store = LocalStore(inMemory: true)
        await store.save(Data("first".utf8), forKey: "key")

        #expect(await store.savedData(forKey: "other") == nil)
    }

    @Test func inMemoryStoresDoNotShareData() async {
        let first = LocalStore(inMemory: true)
        let second = LocalStore(inMemory: true)

        await first.save(Data("first".utf8), forKey: "key")

        #expect(await second.savedData(forKey: "key") == nil)
    }
}
