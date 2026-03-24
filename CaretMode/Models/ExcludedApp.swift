import Foundation

struct ExcludedApp: Identifiable, Codable, Hashable {
    let bundleID: String
    let displayName: String

    var id: String { bundleID }
}
