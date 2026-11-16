import SwiftUI
import UniformTypeIdentifiers
import AppIntents

struct WalletSettings: View {
    @Environment(Store.self) private var store
    @State private var selected: Wallet?
    @State private var showing = false
    @State private var name = ""
    @State private var owner: Person = .agus
    @State private var ext = false
    @State private var card = true
    var body: some View {
        BolsilloList {
            if store.ledger.wallets.contains(where: \.isArchived) {
                DisclosureGroup("Cuentas archivadas") {
                    ForEach(store.ledger.wallets.filter(\.isArchived)) { w in
                        Button("Restaurar \(w.displayName)") { store.commit { data in if let i = data.wallets.firstIndex(where: { $0.id == w.id }) { data.wallets[i].archived = false } } }
                    }
                }
            }
            ForEach(store.ledger.activeWallets) { w in Button { selected = w; name = w.displayName; owner = w.owner; ext = w.isExtension; card = w.isCreditCard; showing = true } label: { HStack { VStack(alignment: .leading) { Text(w.displayName); Text("\(w.owner.title)\(w.isExtension ? " · Extensión" : "")").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "chevron.right") }.foregroundStyle(Palette.text) } } }
            .navigationTitle("Tarjetas y cuentas").toolbar { Button { selected = nil; name = ""; owner = .agus; ext = false; card = true; showing = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $showing) { NavigationStack { BolsilloForm {
                TextField("Nombre", text: $name); Picker("Titular / paga por defecto", selection: $owner) { ForEach(Person.allCases) { Text($0.title).tag($0) } }; Toggle("Es tarjeta de crédito", isOn: $card); if card { Toggle("Es una extensión", isOn: $ext) }
                if card, let selected { NavigationLink("Cierre y vencimiento") { CardScheduleView(walletID: selected.id) } }
                Text("Cambiar el titular no modifica quién pagó gastos ya registrados.").font(.caption)
            }.navigationTitle("Cuenta").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showing = false } }; ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                store.commit { data in if let selected, let i = data.wallets.firstIndex(where: { $0.id == selected.id }) { data.wallets[i].name = name; data.wallets[i].owner = owner; data.wallets[i].isExtension = card && ext; data.wallets[i].creditCard = card } else { data.wallets.append(Wallet(name: name, owner: owner, isExtension: card && ext, creditCard: card)) } }; if store.error == nil { showing = false }
            }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || store.ledger.wallets.contains { $0.name == name && $0.id != selected?.id }) } } } }
    }
}
