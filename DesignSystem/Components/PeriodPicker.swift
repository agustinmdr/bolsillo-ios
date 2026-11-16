import SwiftUI
import Charts
import UniformTypeIdentifiers

struct PeriodPicker: View {
    @Environment(Store.self) private var store
    var title = "Período"
    private var monthName: String {
        store.month.date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "es_AR"))).capitalized
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(title, systemImage: "calendar").font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                Spacer(minLength: 8)
                Menu {
                    ForEach(["ARS", "USD"], id: \.self) { currency in
                        Button { store.currency = currency } label: {
                            if store.currency == currency { Label(currency, systemImage: "checkmark") }
                            else { Text(currency) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.currency)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }.font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12).frame(minHeight: 32).background(Palette.softGreen, in: Capsule())
                        .frame(minHeight: 44)
                }.accessibilityLabel("Moneda: \(store.currency)")
            }
            HStack(spacing: 12) {
                monthButton("chevron.left", label: "Mes anterior", offset: -1)
                VStack(spacing: 2) {
                    Text(monthName).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    Text(String(store.month.year)).font(.caption).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore).accessibilityLabel(store.month.label)
                monthButton("chevron.right", label: "Mes siguiente", offset: 1)
            }
        }.foregroundStyle(Palette.text)
    }
    private func monthButton(_ symbol: String, label: String, offset: Int) -> some View {
        Button { store.month = store.month.adding(offset) } label: {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.accent).frame(width: 44, height: 44)
                .background(Palette.inset, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
