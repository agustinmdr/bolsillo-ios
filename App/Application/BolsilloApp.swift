import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearancePreference"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return .light // Compatibilidad con la preferencia anterior.
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main struct BolsilloApp: App {
    @State private var store = Store.shared
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .light
    @Environment(\.scenePhase) private var scenePhase
    init() { Palette.configureControls() }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Palette.accent)
                .preferredColorScheme(appearance.colorScheme)
                .onOpenURL { url in if url.scheme == "bolsillo" && url.host == "nuevo" { store.month = Month(); store.showAdd = true } }
                .onAppear { store.updateWidget(); store.refreshReminders() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshReminders(); store.cloud.schedule(store: store) } }
        }
    }
}
