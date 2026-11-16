import SwiftUI
import Charts
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Store.self) private var store
    #if DEBUG
    @State private var operationsPreview: OperationsPreviewRoute?
    @State private var didPreview = false
    #endif
    var body: some View {
        @Bindable var store = store
        TabView {
            NavigationStack { Dashboard() }.tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
            NavigationStack { Movements() }.tabItem { Label("Gastos", systemImage: "list.bullet.rectangle") }
            NavigationStack { CoupleView() }.tabItem { Label("Compartidos", systemImage: "person.2.fill") }
            NavigationStack { CategorySettings() }.tabItem { Label("Categorías", systemImage: "square.grid.2x2") }
            NavigationStack { SettingsView() }.tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
        }
        .sheet(isPresented: $store.showAdd) { ExpenseForm() }
        #if DEBUG
        .sheet(item: $operationsPreview) { route in NavigationStack { OperationsPreviewHost(route: route.name) } }
        .onAppear {
            guard !didPreview else { return }; didPreview = true
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-operations=") }) {
                operationsPreview = OperationsPreviewRoute(name: String(argument.dropFirst("--preview-operations=".count)))
            }
        }
        #endif
        .alert("Revisá este cambio", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
