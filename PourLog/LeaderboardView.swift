import SwiftUI

struct LeaderboardView: View {
    @Environment(CloudStore.self) private var store
    @State private var filter: String?

    var body: some View {
        NavigationStack {
            let rows = store.leaderboard(drink: filter)
            List {
                if rows.isEmpty {
                    ContentUnavailableView("No one on the board yet",
                                           systemImage: "trophy",
                                           description: Text("Log a drink and you're in first place."))
                }
                ForEach(rows) { row in
                    LeaderRowView(row: row,
                                  name: store.displayName(for: row.id),
                                  isMe: row.id == store.myID,
                                  showFavorite: filter == nil)
                }
            }
            .refreshable { await store.refresh() }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DrinkFilterMenu(filter: $filter, kinds: store.drinkKinds)
                }
            }
        }
    }
}

struct LeaderRowView: View {
    let row: LeaderRow
    let name: String
    let isMe: Bool
    let showFavorite: Bool

    private var subtitle: String {
        var parts = ["\(row.spots) spot\(row.spots == 1 ? "" : "s")"]
        if let avg = row.avgRating { parts.append(String(format: "avg %.1f★", avg)) }
        if showFavorite && !row.favorite.isEmpty { parts.append("mostly \(row.favorite)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(row.rank)")
                .font(Theme.display(26))
                .monospacedDigit()
                .foregroundStyle(row.rank == 1 ? Theme.gold : Color.secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(name) (you)" : name).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(row.count)").font(.title2.monospacedDigit().weight(.semibold))
                Text(row.count == 1 ? "drink" : "drinks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isMe ? Theme.amber.opacity(0.12) : nil)
    }
}
