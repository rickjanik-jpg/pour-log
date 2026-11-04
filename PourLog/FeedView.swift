import SwiftUI

struct FeedView: View {
    @Environment(CloudStore.self) private var store
    @State private var filter: String?
    @State private var showNew = false

    private var shown: [Pour] {
        guard let filter else { return store.pours }
        return store.pours.filter { $0.drink == filter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.pours.isEmpty && !store.isLoading {
                    ContentUnavailableView {
                        Label("Nothing poured yet", systemImage: "wineglass")
                    } description: {
                        Text(store.errorMessage ?? "Tap + to log your first Old Fashioned — photo, the bar, and a rating.")
                    } actions: {
                        Button("Log a drink") { showNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if let message = store.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                        }
                        ForEach(shown) { pour in
                            NavigationLink(value: pour) {
                                PourCard(pour: pour, who: store.displayName(for: pour.creatorID))
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions {
                                if pour.creatorID == store.myID {
                                    Button("Delete", role: .destructive) {
                                        Task { await store.delete(pour) }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.refresh() }
                }
            }
            .overlay {
                if store.isLoading && store.pours.isEmpty { ProgressView() }
            }
            .navigationTitle("The Muddler")
            .navigationDestination(for: Pour.self) { pour in
                PourDetailView(pour: pour)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DrinkFilterMenu(filter: $filter, kinds: store.drinkKinds)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Log a drink")
                }
            }
            .sheet(isPresented: $showNew) { NewPourView() }
        }
    }
}

struct DrinkFilterMenu: View {
    @Binding var filter: String?
    let kinds: [String]

    var body: some View {
        Menu {
            Picker("Drink", selection: $filter) {
                Text("All drinks").tag(String?.none)
                ForEach(kinds, id: \.self) { kind in
                    Text(kind).tag(String?.some(kind))
                }
            }
        } label: {
            Label(filter ?? "All drinks", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
        }
    }
}

struct PourCard: View {
    let pour: Pour
    let who: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = pour.photoURL {
                PhotoView(url: url).frame(height: 240)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pour.drink).font(Theme.display(22))
                    Spacer()
                    if pour.rating > 0 { StarsLabel(rating: pour.rating) }
                }
                if !pour.placeLine.isEmpty {
                    if let maps = pour.mapsURL {
                        Link(destination: maps) {
                            Label(pour.placeLine, systemImage: "mappin.and.ellipse")
                        }
                        .font(.subheadline)
                    } else {
                        Label(pour.placeLine, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                }
                if !pour.notes.isEmpty {
                    Text(pour.notes).font(.subheadline)
                }
                HStack {
                    Text(who)
                    Spacer()
                    Text(pour.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

                // Social row
                HStack(spacing: 14) {
                    CardLikeButton(pour: pour)
                    if pour.commentCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                            Text("\(pour.commentCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Loads a CloudKit photo from its local cache file without blocking scrolling.
struct PhotoView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.amber.opacity(0.12))
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: url) {
                let path = url.path
                image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard let full = UIImage(contentsOfFile: path) else { return nil }
                    let w: CGFloat = 1000
                    let h = w * full.size.height / max(full.size.width, 1)
                    return await full.byPreparingThumbnail(ofSize: CGSize(width: w, height: h)) ?? full
                }.value
            }
    }
}

/// A heart button on the feed card — tapping it toggles the like without navigating.
struct CardLikeButton: View {
    @Environment(CloudStore.self) private var store
    let pour: Pour

    private var current: Pour { store.pours.first(where: { $0.id == pour.id }) ?? pour }

    var body: some View {
        Button {
            Task { await store.toggleLike(current) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: current.likedByMe ? "heart.fill" : "heart")
                    .foregroundStyle(current.likedByMe ? Color.red : Color.secondary)
                if current.likeCount > 0 {
                    Text("\(current.likeCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

struct StarsLabel: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.gold)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}
