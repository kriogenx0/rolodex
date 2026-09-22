import Foundation

struct RolodexData: Codable {
    var smartGroups: [SmartGroup] = []
    var hiddenGroupIdentifiers: Set<String> = []
    var blockedContactIdentifiers: Set<String> = []
}

@MainActor
final class AppDataStore {
    static let shared = AppDataStore()

    private let fileURL: URL
    private(set) var data: RolodexData

    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rolodexDir = supportDir.appendingPathComponent("Rolodex", isDirectory: true)
        try? FileManager.default.createDirectory(at: rolodexDir, withIntermediateDirectories: true)
        fileURL = rolodexDir.appendingPathComponent("rolodex-data.json")

        if let contents = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(RolodexData.self, from: contents) {
            data = decoded
        } else {
            data = RolodexData()
        }
    }

    func update(_ mutate: (inout RolodexData) -> Void) {
        mutate(&data)
        save()
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Rolodex: failed to save local data: \(error)")
        }
    }
}
