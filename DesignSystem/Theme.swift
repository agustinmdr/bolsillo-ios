import SwiftUI
import UIKit

/// Paleta única para la app y el widget. Sin superficies blancas en el tema claro.
enum Palette {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let mint = Color(red: 0.07, green: 0.39, blue: 0.30)
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.15)
    static let paper = adaptive(0xF0F0E9, 0x101714)
    static let surface = adaptive(0xFAF8F1, 0x1A2520)
    static let inset = adaptive(0xECEEE5, 0x223129)
    static let softGreen = adaptive(0xE2EBDD, 0x2B4233)
    static let outline = adaptive(0xDCDDD2, 0x34463A)
    static let text = adaptive(0x253A2F, 0xEEF1E8)
    static let muted = adaptive(0x60695F, 0xADB8AC)
    static let accent = adaptive(0x176449, 0xAAD1B0)
    static let shadow = adaptive(0x233A2E, 0x000000).opacity(0.045)
    static let onBrand = Color(red: 0.98, green: 0.94, blue: 0.85)
    static let danger = adaptive(0xA14532, 0xF0AA93)
    static let warning = adaptive(0x79571D, 0xE7C17C)
    static let chart: [Color] = [accent, adaptive(0x9B7446, 0xD6AE79), adaptive(0x687753, 0xB6C88C), adaptive(0xA05D48, 0xDD9A7F), adaptive(0x526F68, 0x8FBCAF), adaptive(0x807454, 0xCDBE95), adaptive(0x746A65, 0xC4B1A5), adaptive(0x7C6944, 0xCEB57B), adaptive(0x8D6260, 0xD7A9A5), adaptive(0x516C43, 0xA5BF8B), adaptive(0x74754F, 0xD0CC9A)]
    static func categoryColor(_ category: Category) -> Color {
        // Índice persistente: editar nombre, ordenar por importe o crear categorías
        // no cambia el color de las que ya existen.
        let fallback = category.id.uuidString.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
        let index = category.colorIndex ?? Int(fallback % 10000)
        let colors: [Color] = [adaptive(0x286B55, 0x8CC9AA), adaptive(0xC39739, 0xE5BF65), adaptive(0x4E83A8, 0x83BADB), adaptive(0xC07558, 0xE4A183), adaptive(0x8B76AB, 0xBBA6D8), adaptive(0x78A09A, 0x9ED1C5), adaptive(0xAA6D85, 0xDC9BB5), adaptive(0x8C9B50, 0xBDCD82), adaptive(0xC18838, 0xE1B568), adaptive(0x627F9B, 0x9FB8D4), adaptive(0xA16A4D, 0xD6A38A), adaptive(0x8D9274, 0xBCC2A2), adaptive(0x90958D, 0xA7B1A5)]
        if colors.indices.contains(index) { return colors[index] }
        return Color(hue: (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1), saturation: 0.42, brightness: 0.72)
    }

    static func configureControls() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = UIColor(paper)
        navigation.titleTextAttributes = [.foregroundColor: UIColor(text)]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor(text)]
        navigation.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(paper)
        tab.shadowColor = UIColor(outline)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(muted)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(muted)]
            item.selected.iconColor = UIColor(accent)
            item.selected.titleTextAttributes = [.foregroundColor: UIColor(accent)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UISearchTextField.appearance().backgroundColor = UIColor(surface)
        UISearchTextField.appearance().textColor = UIColor(text)
        UISwitch.appearance().onTintColor = UIColor(mint)
        UISwitch.appearance().thumbTintColor = UIColor(onBrand)
        UISlider.appearance().minimumTrackTintColor = UIColor(accent)
        UISlider.appearance().maximumTrackTintColor = UIColor(outline)
        UISlider.appearance().thumbTintColor = UIColor(onBrand)
    }
}

private struct BolsilloScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Palette.text)
            .tint(Palette.accent)
            .background(Palette.paper.ignoresSafeArea())
            .toolbarBackground(Palette.paper, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .presentationBackground(Palette.paper)
    }
}
extension View {
    func bolsilloScreen() -> some View { modifier(BolsilloScreenStyle()) }
    func bolsilloCard(radius: CGFloat = 20) -> some View {
        background(Palette.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Palette.outline.opacity(0.7), lineWidth: 0.7))
            .compositingGroup()
            .shadow(color: Palette.shadow, radius: 10, x: 0, y: 4)
    }
}

/// El color de fila debe aplicarse al contenido, no al contenedor List/Form.
struct BolsilloList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        List {
            content.listRowBackground(Palette.surface).listRowSeparatorTint(Palette.outline).listSectionSeparatorTint(Palette.outline)
        }.scrollContentBackground(.hidden).bolsilloScreen()
    }
}
struct BolsilloForm<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        Form {
            content.listRowBackground(Palette.surface).listRowSeparatorTint(Palette.outline).listSectionSeparatorTint(Palette.outline)
        }.scrollContentBackground(.hidden).bolsilloScreen()
    }
}

struct BolsilloDivider: View {
    var body: some View { Rectangle().fill(Palette.outline).frame(height: 0.5).accessibilityHidden(true) }
}

// Color + símbolo + texto: la responsabilidad no depende solo del color.
extension Allocation {
    var ownershipColor: Color {
        switch self {
        case .mine: Palette.accent
        case .shared: Palette.adaptive(0x79531B, 0xF0C77A)
        case .mai: Palette.adaptive(0x4C6198, 0xADBEF2)
        }
    }
    var ownershipBackground: Color {
        switch self {
        case .mine: Palette.softGreen
        case .shared: Palette.adaptive(0xF3E6C9, 0x3C3222)
        case .mai: Palette.adaptive(0xE5EAF7, 0x29324A)
        }
    }
}
struct AllocationBadge: View {
    let allocation: Allocation
    var body: some View {
        Label(allocation.title, systemImage: allocation.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(allocation.ownershipColor)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(allocation.ownershipBackground, in: Capsule())
            .accessibilityLabel("Responsabilidad: \(allocation.title)")
    }
}
