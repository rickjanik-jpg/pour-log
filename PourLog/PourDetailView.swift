import SwiftUI

struct PourDetailView: View {
    @Environment(CloudStore.self) private var store
    var pour: Pour

    @State private var comments: [Comment] = []
    @State private var commentText = ""
    @State private var submitting = false
    @State private var loadingComments = true
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Photo or placeholder
                if let url = pour.photoURL {
                    PhotoView(url: url).frame(height: 280)
                } else {
                    Rectangle()
                        .fill(Theme.amber.opacity(0.08))
                        .frame(height: 160)
                        .overlay {
                            Image(systemName: "wineglass")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.amber.opacity(0.3))
                        }
                }

                VStack(alignment: .leading, spacing: 12) {

                    // Drink + stars
                    HStack(alignment: .firstTextBaseline) {
                        Text(pour.drink).font(Theme.display(26))
                        Spacer()
                        if pour.rating > 0 { StarsLabel(rating: pour.rating) }
                    }
                    .padding(.top, 16)

                    // Venue
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

                    // Notes
                    if !pour.notes.isEmpty {
                        Text(pour.notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Who + when
                    HStack {
                        Text(store.displayName(for: pour.creatorID))
                        Spacer()
                        Text(pour.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)

                    // Like row
                    LikeRow(pour: pour)
                        .padding(.vertical, 4)

                    Divider()

                    // Comments header
                    Text("Comments")
                        .font(.headline)
                        .padding(.top, 4)

                    if loadingComments {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 20)
                    } else if comments.isEmpty {
                        Text("No comments yet — be the first.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, store: store)
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            CommentComposer(
                text: $commentText,
                focused: $inputFocused,
                submitting: submitting
            ) {
                await submitComment()
            }
        }
        .task {
            await store.loadLikes(for: pour)
            comments = await store.loadComments(for: pour)
            loadingComments = false
        }
    }

    private func submitComment() async {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitting = true
        commentText = ""
        inputFocused = false
        if let c = try? await store.addComment(to: pour, text: trimmed) {
            comments.append(c)
        }
        submitting = false
    }
}

// MARK: - Like Row

struct LikeRow: View {
    @Environment(CloudStore.self) private var store
    var pour: Pour

    private var current: Pour { store.pours.first(where: { $0.id == pour.id }) ?? pour }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                Task { await store.toggleLike(current) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: current.likedByMe ? "heart.fill" : "heart")
                        .foregroundStyle(current.likedByMe ? Color.red : Color.secondary)
                    if current.likeCount > 0 {
                        Text("\(current.likeCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            if current.commentCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                    Text("\(current.commentCount)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment
    let store: CloudStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.amber.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(store.displayName(for: comment.creatorID).prefix(1)))
                        .font(.caption.bold())
                        .foregroundStyle(Theme.amber)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.displayName(for: comment.creatorID))
                        .font(.caption.bold())
                    Text(comment.createdAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(comment.text)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Comment Composer

struct CommentComposer: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var submitting: Bool
    var onSubmit: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused(focused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await onSubmit() }
            } label: {
                Image(systemName: submitting ? "ellipsis" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Theme.amber)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
