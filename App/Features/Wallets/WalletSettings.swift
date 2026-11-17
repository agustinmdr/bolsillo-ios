import SwiftUI

struct WalletSettings: View {
    @Environment(Store.self) private var store
    @State private var selected: Wallet?
    @State private var showing = false
    @State private var name = ""
    @State private var owner: Person = .agus
    @State private var ext = false
    @State private var card = true
    @State private var removing: Wallet?
    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicateName: Bool {
        store.ledger.wallets.contains { normalized($0.displayName) == normalized(cleanName) && $0.id != selected?.id }
    }
    var body: some View {
        BolsilloList {
            Section {
                Button { beginNew(card: true) } label: { Label("Agregar tarjeta", systemImage: "plus.circle.fill") }
                Button { beginNew(card: false) } label: { Label("Agregar cuenta o efectivo", systemImage: "banknote") }
            }
            Section("Tarjetas") {
                if store.ledger.creditCards.isEmpty { Text("Todavía no agregaste tarjetas.").foregroundStyle(Palette.muted) }
                ForEach(store.ledger.creditCards) { wallet in walletRow(wallet) }
            }
            Section("Otras cuentas") {
                ForEach(store.ledger.activeWallets.filter { !$0.isCreditCard }) { wallet in walletRow(wallet) }
            }
            if store.ledger.wallets.contains(where: \.isArchived) {
                Section {
                    DisclosureGroup("Tarjetas y cuentas quitadas") {
                        ForEach(store.ledger.wallets.filter(\.isArchived)) { wallet in
                            HStack {
                                Text(wallet.displayName).lineLimit(1).truncationMode(.tail)
                                Spacer()
                                Button("Restaurar") { setArchived(wallet, false) }.buttonStyle(.borderless)
                                    .accessibilityLabel("Restaurar \(wallet.displayName)")
                            }
                        }
                    }
                } footer: { Text("Quitar una tarjeta conserva sus gastos y resúmenes. Podés restaurarla cuando quieras.") }
            }
        }.navigationTitle("Tarjetas y cuentas").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button { beginNew(card: true) } label: { Image(systemName: "plus") }.accessibilityLabel("Agregar tarjeta") }
            .sheet(isPresented: $showing) {
                NavigationStack {
                    BolsilloForm {
                        Section("Datos") {
                            TextField("Nombre de la tarjeta o cuenta", text: $name)
                            if duplicateName { Text("Ya existe ese nombre. Si la quitaste, podés restaurarla desde la lista.").font(.caption).foregroundStyle(Palette.danger) }
                            Picker("Titular / paga por defecto", selection: $owner) { ForEach(Person.allCases) { Text($0.title).tag($0) } }
                            Toggle("Es tarjeta de crédito", isOn: $card)
                            if card { Toggle("Es una extensión", isOn: $ext) }
                        }
                        if card, let selected { Section { NavigationLink("Cierre y vencimiento") { CardScheduleView(walletID: selected.id) } } }
                        Section { Text("Cambiar el titular no modifica quién pagó gastos ya registrados.").font(.caption).foregroundStyle(Palette.muted) }
                        if let selected {
                            Section { Button("Quitar \(selected.isCreditCard ? "tarjeta" : "cuenta")", role: .destructive) { removing = selected } }
                        }
                    }.navigationTitle(selected == nil ? (card ? "Nueva tarjeta" : "Nueva cuenta") : "Editar medio de pago")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showing = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(cleanName.isEmpty || duplicateName) }
                        }
                        .confirmationDialog("¿Quitar \(removing?.displayName ?? "este medio de pago")?", isPresented: sheetRemoval) { removalButton } message: { removalMessage }
                }
            }
            .confirmationDialog("¿Quitar \(removing?.displayName ?? "este medio de pago")?", isPresented: listRemoval) { removalButton } message: { removalMessage }
    }
    private var sheetRemoval: Binding<Bool> { Binding(get: { showing && removing != nil }, set: { if !$0 { removing = nil } }) }
    private var listRemoval: Binding<Bool> { Binding(get: { !showing && removing != nil }, set: { if !$0 { removing = nil } }) }
    private var removalMessage: Text { Text("Dejará de aparecer al cargar gastos nuevos. Sus gastos y resúmenes se conservan; podés restaurarla desde Tarjetas y cuentas quitadas.") }
    @ViewBuilder private var removalButton: some View {
        if let wallet = removing { Button("Quitar", role: .destructive) { setArchived(wallet, true); if store.error == nil { showing = false }; removing = nil } }
    }
    private func walletRow(_ wallet: Wallet) -> some View {
        Button {
            selected = wallet; name = wallet.displayName; owner = wallet.owner; ext = wallet.isExtension; card = wallet.isCreditCard; showing = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: wallet.isCreditCard ? "creditcard" : "banknote").foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.displayName).lineLimit(1).truncationMode(.tail)
                    Text("\(wallet.owner.title)\(wallet.isExtension ? " · Extensión" : "")").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
            }.foregroundStyle(Palette.text)
        }.swipeActions { Button("Quitar", role: .destructive) { removing = wallet } }
    }
    private func beginNew(card: Bool) {
        selected = nil; name = ""; owner = .agus; ext = false; self.card = card; showing = true
    }
    private func setArchived(_ wallet: Wallet, _ value: Bool) {
        store.commit { ledger in if let i = ledger.wallets.firstIndex(where: { $0.id == wallet.id }) { ledger.wallets[i].archived = value } }
    }
    private func save() {
        store.commit { ledger in
            if let selected, let i = ledger.wallets.firstIndex(where: { $0.id == selected.id }) {
                ledger.wallets[i].name = cleanName; ledger.wallets[i].owner = owner
                ledger.wallets[i].isExtension = card && ext; ledger.wallets[i].creditCard = card
            } else { ledger.wallets.append(Wallet(name: cleanName, owner: owner, isExtension: card && ext, creditCard: card)) }
        }
        if store.error == nil { showing = false }
    }
}
