import CoreData

/// Saves small pieces of data by key (API pages, recent searches) so the app works offline.
nonisolated protocol LocalStoring: Sendable {
    func savedData(forKey key: String) async -> SavedData?
    func save(_ data: Data, forKey key: String) async
    /// Deletes all but the `count` most recently saved values whose keys start with `prefix`.
    func removeSavedData(withKeyPrefix prefix: String, keepingNewest count: Int) async
}

nonisolated struct SavedData: Sendable {
    let data: Data
    let savedAt: Date
}

/// Core Data, one row per key. A damaged store is rebuilt; any other failure falls back to memory.
nonisolated final class LocalStore: LocalStoring, @unchecked Sendable {
    private enum Constants {
        static let containerName = "LocalStore"
        static let fileName = "LocalStore.sqlite"
        static let entityName = "StoredValue"
        static let keyAttribute = "key"
        static let payloadAttribute = "payload"
        static let savedAtAttribute = "savedAt"
        static let inMemoryURL = URL(fileURLWithPath: "/dev/null")
        /// Load errors that mean the file itself is unusable, so rebuilding it loses nothing readable.
        static let unusableStoreErrorCodes: Set<Int> = [
            NSFileReadCorruptFileError,
            NSPersistentStoreIncompatibleVersionHashError,
            NSPersistentStoreIncompatibleSchemaError,
            NSMigrationMissingSourceModelError
        ]
    }

    private static var storeURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory.appendingPathComponent(Constants.fileName)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    /// Built once in code: loading the same entity from two models confuses Core Data in tests.
    /// Never mutated after creation, so sharing it across threads is safe.
    nonisolated(unsafe) private static let model: NSManagedObjectModel = {
        let entity = NSEntityDescription()
        entity.name = Constants.entityName
        let key = NSAttributeDescription()
        key.name = Constants.keyAttribute
        key.attributeType = .stringAttributeType
        let payload = NSAttributeDescription()
        payload.name = Constants.payloadAttribute
        payload.attributeType = .binaryDataAttributeType
        payload.allowsExternalBinaryDataStorage = true
        let savedAt = NSAttributeDescription()
        savedAt.name = Constants.savedAtAttribute
        savedAt.attributeType = .dateAttributeType
        entity.properties = [key, payload, savedAt]
        entity.uniquenessConstraints = [[Constants.keyAttribute]]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }()

    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Constants.containerName, managedObjectModel: Self.model)
        let description = NSPersistentStoreDescription()
        description.url = inMemory ? Constants.inMemoryURL : Self.storeURL
        container.persistentStoreDescriptions = [description]
        loadStores(recoveringFrom: description)
    }

    func savedData(forKey key: String) async -> SavedData? {
        await container.performBackgroundTask { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
            request.predicate = NSPredicate(format: "%K == %@", Constants.keyAttribute, key)
            request.fetchLimit = 1
            guard let object = try? context.fetch(request).first,
                  let data = object.value(forKey: Constants.payloadAttribute) as? Data,
                  let savedAt = object.value(forKey: Constants.savedAtAttribute) as? Date else { return nil }
            return SavedData(data: data, savedAt: savedAt)
        }
    }

    func save(_ data: Data, forKey key: String) async {
        await container.performBackgroundTask { context in
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            let object = NSEntityDescription.insertNewObject(forEntityName: Constants.entityName, into: context)
            object.setValue(key, forKey: Constants.keyAttribute)
            object.setValue(data, forKey: Constants.payloadAttribute)
            object.setValue(Date(), forKey: Constants.savedAtAttribute)
            try? context.save()
        }
    }

    func removeSavedData(withKeyPrefix prefix: String, keepingNewest count: Int) async {
        await container.performBackgroundTask { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
            request.predicate = NSPredicate(format: "%K BEGINSWITH %@", Constants.keyAttribute, prefix)
            request.sortDescriptors = [NSSortDescriptor(key: Constants.savedAtAttribute, ascending: false)]
            request.fetchOffset = count
            request.includesPropertyValues = false
            guard let stale = try? context.fetch(request), !stale.isEmpty else { return }
            stale.forEach(context.delete)
            try? context.save()
        }
    }

    private func loadStores(recoveringFrom description: NSPersistentStoreDescription) {
        guard let error = loadPersistentStores() else { return }
        if let url = description.url, Self.isUnusableStore(error) {
            try? container.persistentStoreCoordinator.destroyPersistentStore(at: url, type: .sqlite)
            guard loadPersistentStores() != nil else { return }
        }
        description.url = Constants.inMemoryURL
        container.persistentStoreDescriptions = [description]
        _ = loadPersistentStores()
    }

    /// Loads synchronously: the default store description adds stores on the calling thread.
    private func loadPersistentStores() -> Error? {
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        return loadError
    }

    private static func isUnusableStore(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && Constants.unusableStoreErrorCodes.contains(error.code)
    }
}
