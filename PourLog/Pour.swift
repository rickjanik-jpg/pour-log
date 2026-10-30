import Foundation
import CloudKit
import CoreLocation

/// One logged drink. Stored in the CloudKit public database as a "Pour" record.
struct Pour: Identifiable, Hashable {
    static let recordType = "Pour"

    let id: CKRecord.ID
    var drink: String
    var venue: String
    var city: String
    var notes: String
    var rating: Int
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var photoURL: URL?
    /// The iCloud user record name of whoever logged it.
    var creatorID: String?

    init(record: CKRecord, myID: String?) {
        id = record.recordID
        drink = record["drink"] as? String ?? "Drink"
        venue = record["venue"] as? String ?? ""
        city = record["city"] as? String ?? ""
        notes = record["notes"] as? String ?? ""
        rating = record["rating"] as? Int ?? 0
        if let loc = record["location"] as? CLLocation {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
        }
        createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .distantPast
        photoURL = (record["photo"] as? CKAsset)?.fileURL
        // CloudKit reports your own records as "__defaultOwner__"; swap in your real id
        // so the leaderboard groups your drinks together.
        let raw = record.creatorUserRecordID?.recordName
        creatorID = (raw == nil || raw == CKCurrentUserDefaultName) ? myID : raw
    }

    var placeLine: String {
        [venue, city].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var mapsURL: URL? {
        guard let latitude, let longitude else { return nil }
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: venue.isEmpty ? drink : venue)
        ]
        return c.url
    }
}

struct LeaderRow: Identifiable {
    let id: String          // creator's user record name
    var rank: Int
    let count: Int
    let spots: Int
    let avgRating: Double?
    let favorite: String
}
