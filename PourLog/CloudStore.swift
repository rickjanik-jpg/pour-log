import Foundation
import CloudKit
import CoreLocation
import Observation
import UIKit

/// Talks to the CloudKit public database, so everyone using the app shares one log.
@MainActor
@Observable
final class CloudStore {
    // ⚠️ Change this to the container you create under Signing & Capabilities → iCloud.
    static let containerID = "iCloud.com.yourname.PourLog"

    @ObservationIgnored private let container = CKContainer(identifier: CloudStore.containerID)
    private var db: CKDatabase { container.publicCloudDatabase }

    var pours: [Pour] = []
    var names: [String: String] = [:]      // user record name → display name
    var myID: String?
    var myName = ""
    var isLoading = false
    var didLoad = false
    var accountAvailable = true
    var errorMessage: String?

    var needsName: Bool { didLoad && accountAvailable && myID != nil && myName.isEmpty }

    // MARK: Loading

    func bootstrap() async {
        do {
            let status = try await container.accountStatus()
            accountAvailable = (status == .available)
            guard accountAvailable else {
                errorMessage = "Sign in to iCloud in Settings to share drinks with friends."
                return
            }
            myID = try await container.userRecordID().recordName
            await refresh()
        } catch {
            errorMessage = friendly(error)
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false; didLoad = true }
        do {
            let query = CKQuery(recordType: Pour.recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let (results, _) = try await db.records(matching: query, resultsLimit: 400)
            pours = results.compactMap { try? $0.1.get() }.map { Pour(record: $0, myID: myID) }
            errorMessage = nil
        } catch let ck as CKError where ck.code == .unknownItem {
            // Record type doesn't exist until the first drink is saved.
            pours = []
            errorMessage = nil
        } catch {
            errorMessage = friendly(error)
        }
        await loadNames()
    }

    private func loadNames() async {
        var ids = Set(pours.compactMap(\.creatorID))
        if let myID { ids.insert(myID) }
        guard !ids.isEmpty else { return }
        let recordIDs = ids.map { CKRecord.ID(recordName: "drinker-" + $0) }
        guard let results = try? await db.records(for: recordIDs) else { return }
        for (rid, result) in results {
            if let rec = try? result.get(), let name = rec["name"] as? String {
                names[String(rid.recordName.dropFirst("drinker-".count))] = name
            }
        }
        if let myID, let n = names[myID] { myName = n }
    }

    // MARK: Writing

    func setName(_ name: String) async throws {
        guard let myID else { return }
        let rid = CKRecord.ID(recordName: "drinker-" + myID)
        let record: CKRecord
        if let existing = try? await db.record(for: rid) {
            record = existing
        } else {
            record = CKRecord(recordType: "Drinker", recordID: rid)
        }
        record["name"] = name
        _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        myName = name
        names[myID] = name
    }

    func add(drink: String, venue: String, city: String, notes: String,
             rating: Int, location: CLLocation?, image: UIImage?) async throws {
        let rec = CKRecord(recordType: Pour.recordType)
        rec["drink"] = drink
        rec["venue"] = venue
        rec["city"] = city
        rec["notes"] = notes
        rec["rating"] = rating
        rec["createdAt"] = Date()
        if let location { rec["location"] = location }
        if let image, let data = image.resizedJPEG(maxSide: 1600) {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            try data.write(to: url)
            rec["photo"] = CKAsset(fileURL: url)
        }
        let saved = try await db.save(rec)
        // Show it right away; public-database queries can take a few seconds to catch up.
        pours.insert(Pour(record: saved, myID: myID), at: 0)
    }

    func delete(_ pour: Pour) async {
        do {
            try await db.deleteRecord(withID: pour.id)
            pours.removeAll { $0.id == pour.id }
        } catch {
            errorMessage = friendly(error)
        }
    }

    // MARK: Derived data

    func displayName(for id: String?) -> String {
        guard let id else { return "Someone" }
        if let n = names[id], !n.isEmpty { return n }
        return id == myID ? "You" : "Someone"
    }

    var drinkKinds: [String] {
        Dictionary(grouping: pours, by: \.drink)
            .sorted { $0.value.count > $1.value.count }
            .map(\.key)
    }

    func leaderboard(drink: String?) -> [LeaderRow] {
        let list = drink.map { d in pours.filter { $0.drink == d } } ?? pours
        let groups = Dictionary(grouping: list.filter { $0.creatorID != nil }, by: { $0.creatorID! })
        var rows: [LeaderRow] = groups.map { id, ps in
            let rated = ps.filter { $0.rating > 0 }
            let avg: Double? = rated.isEmpty ? nil
                : Double(rated.map(\.rating).reduce(0, +)) / Double(rated.count)
            let fav = Dictionary(grouping: ps, by: \.drink)
                .max { $0.value.count < $1.value.count }?.key ?? ""
            return LeaderRow(id: id, rank: 0, count: ps.count,
                             spots: Set(ps.map { $0.venue.lowercased() }).count,
                             avgRating: avg, favorite: fav)
        }
        rows.sort { ($0.count, $0.spots) > ($1.count, $1.spots) }
        var rank = 0, previous = -1
        for i in rows.indices {
            if rows[i].count != previous { rank = i + 1; previous = rows[i].count }
            rows[i].rank = rank
        }
        return rows
    }

    func friendly(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Sign in to iCloud in Settings to share drinks."
        case .networkUnavailable, .networkFailure: return "No connection. Pull to refresh when you're back online."
        case .quotaExceeded: return "iCloud storage is full."
        case .permissionFailure: return "You can only change your own entries."
        default: return ck.localizedDescription
        }
    }
}
