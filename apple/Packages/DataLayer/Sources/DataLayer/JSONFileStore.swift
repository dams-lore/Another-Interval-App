import Foundation

/// Stockage local d'une liste d'éléments dans un fichier JSON (écriture atomique).
/// Simple et testable ; remplaçable plus tard par GRDB (docs/architecture.md § 8) derrière les mêmes protocoles.
actor JSONFileStore<Item: Codable & Identifiable & Sendable> where Item.ID: Sendable {
    private let url: URL
    private var cache: [Item]?

    init(url: URL) { self.url = url }

    func all() -> [Item] { load() }

    func upsert(_ item: Item) throws {
        var items = load()
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
        try write(items)
    }

    func remove(id: Item.ID) throws {
        var items = load()
        items.removeAll { $0.id == id }
        try write(items)
    }

    private func load() -> [Item] {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: url.path) else {
            cache = []
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let items = try Self.decoder.decode([Item].self, from: data)
            cache = items
            return items
        } catch {
            // Fichier illisible : on le met de côté (jamais écrasé) et on repart d'une liste vide.
            let backup = url.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            cache = []
            return []
        }
    }

    private func write(_ items: [Item]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encoder.encode(items)
        try data.write(to: url, options: .atomic)
        cache = items
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
