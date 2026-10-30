import SwiftUI

struct RootView: View {
    @Environment(CloudStore.self) private var store
    @State private var askName = false

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "wineglass") }
            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "trophy") }
            ProfileView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
        .onChange(of: store.needsName) { _, needs in
            if needs { askName = true }
        }
        .sheet(isPresented: $askName) { NameSheet() }
    }
}

struct NameSheet: View {
    @Environment(CloudStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $name)
                        .textContentType(.nickname)
                } header: {
                    Text("How you'll appear on the leaderboard")
                } footer: {
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Your name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            saving = true
                            defer { saving = false }
                            do {
                                try await store.setName(name.trimmed)
                                dismiss()
                            } catch {
                                self.error = store.friendly(error)
                            }
                        }
                    }
                    .disabled(name.trimmed.isEmpty || saving)
                }
            }
            .onAppear { name = store.myName }
        }
        .presentationDetents([.medium])
    }
}

struct ProfileView: View {
    @Environment(CloudStore.self) private var store
    @State private var editing = false

    private var mine: [Pour] { store.pours.filter { $0.creatorID == store.myID } }
    private var usual: String? {
        Dictionary(grouping: mine, by: \.drink).max { $0.value.count < $1.value.count }?.key
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Leaderboard name") {
                    HStack {
                        Text(store.myName.isEmpty ? "Not set" : store.myName)
                            .foregroundStyle(store.myName.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("Edit") { editing = true }
                    }
                }
                Section("Your stats") {
                    LabeledContent("Drinks", value: "\(mine.count)")
                    LabeledContent("Spots", value: "\(Set(mine.map { $0.venue.lowercased() }).count)")
                    if let usual { LabeledContent("Usual", value: usual) }
                }
                if !store.accountAvailable {
                    Section {
                        Text("Sign in to iCloud in Settings to share drinks with friends.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Me")
            .sheet(isPresented: $editing) { NameSheet() }
        }
    }
}
