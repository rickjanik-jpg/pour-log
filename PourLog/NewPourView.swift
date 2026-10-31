import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct NewPourView: View {
    @Environment(CloudStore.self) private var store
    @Environment(LocationService.self) private var locator
    @Environment(\.dismiss) private var dismiss

    @State private var drink = Drinks.all[0]
    @State private var otherDrink = ""
    @State private var venue = ""
    @State private var city = ""
    @State private var notes = ""
    @State private var rating = 0

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var location: CLLocation?
    @State private var locationSource: LocationSource = .none
    @State private var nearby: [MKMapItem] = []
    @State private var locating = false

    @State private var saving = false
    @State private var error: String?

    enum LocationSource { case none, here, photo }

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private var finalDrink: String {
        guard drink == "Other" else { return drink }
        return otherDrink.trimmed.isEmpty ? "Other" : otherDrink.trimmed
    }

    private var locationFooter: String {
        switch locationSource {
        case .photo: return "Using the location saved in your photo."
        case .here: return "Using your current location."
        case .none:
            return locator.denied
                ? "Location is off for Pour Log. Turn it on in Settings to get nearby suggestions."
                : ""
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                    HStack {
                        if cameraAvailable {
                            Button { showCamera = true } label: {
                                Label("Camera", systemImage: "camera")
                            }
                            .buttonStyle(.borderless)
                        }
                        Spacer()
                        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                            Label("Library", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Drink") {
                    Picker("Drink", selection: $drink) {
                        ForEach(Drinks.all, id: \.self) { Text($0) }
                    }
                    if drink == "Other" {
                        TextField("What was it?", text: $otherDrink)
                    }
                    StarPicker(rating: $rating)
                }

                Section {
                    TextField("Bar or restaurant", text: $venue)
                    TextField("City", text: $city)
                    if locating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Finding nearby spots…").foregroundStyle(.secondary)
                        }
                    }
                    if !nearby.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(nearby, id: \.self) { item in
                                    Button(item.name ?? "Unnamed") {
                                        venue = item.name ?? ""
                                        if let loc = item.placemark.location { location = loc }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(venue == item.name ? Theme.amber : Color.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Where")
                } footer: {
                    Text(locationFooter)
                }

                Section("Notes") {
                    TextField("Bourbon or rye? Demerara or simple? Orange peel or cherry? Worth the drive?",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New pour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(venue.trimmed.isEmpty || saving)
                }
            }
            .task { await locateHere() }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPicked(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $image).ignoresSafeArea()
            }
            .interactiveDismissDisabled(saving)
        }
    }

    // MARK: Location

    private func locateHere() async {
        guard locationSource == .none else { return }
        locating = true
        defer { locating = false }
        guard let loc = await locator.currentLocation() else { return }
        if locationSource == .photo { return }   // a library photo's location already won
        await apply(loc, source: .here)
    }

    private func apply(_ loc: CLLocation, source: LocationSource) async {
        location = loc
        locationSource = source
        nearby = []
        async let places = locator.nearbyPlaces(around: loc)
        async let town = locator.cityName(for: loc)
        nearby = await places
        let townName = await town
        if !townName.isEmpty { city = townName }
        // Prefill the venue only when you're basically standing in it.
        if venue.trimmed.isEmpty, let first = nearby.first,
           let d = first.placemark.location?.distance(from: loc), d < 40 {
            venue = first.name ?? ""
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else { return }
        image = picked
        var loc = PhotoLocation.fromMetadata(data)
        if loc == nil, let id = item.itemIdentifier {
            loc = await PhotoLocation.fromLibrary(id)
        }
        if let loc { await apply(loc, source: .photo) }
    }

    // MARK: Save

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await store.add(drink: finalDrink, venue: venue.trimmed, city: city.trimmed,
                                notes: notes.trimmed, rating: rating,
                                location: location, image: image)
            dismiss()
        } catch {
            self.error = store.friendly(error)
        }
    }
}

struct StarPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("Rating")
            Spacer()
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = (rating == i) ? 0 : i
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(i <= rating ? Theme.gold : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
            }
        }
    }
}
