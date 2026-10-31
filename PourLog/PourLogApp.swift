import SwiftUI

@main
struct PourLogApp: App {
    @State private var store = CloudStore()
    @State private var locator = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(locator)
                .tint(Theme.amber)
                .task { await store.bootstrap() }
        }
    }
}

enum Theme {
    static let amber = Color(red: 0.72, green: 0.40, blue: 0.13)
    static let gold = Color(red: 0.83, green: 0.62, blue: 0.22)

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

enum Drinks {
    static let all = [
        "Old Fashioned",           // the classic
        "Bourbon Old Fashioned",
        "Rye Old Fashioned",
        "Mezcal Old Fashioned",
        "Rum Old Fashioned",
        "Brandy Old Fashioned",    // Wisconsin style
        "Tequila Old Fashioned",
        "Other Old Fashioned",
    ]
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
