import SwiftUI
import UIKit

/// Observa toques sin interceptar botones, menús ni la edición de otros campos.
private struct KeyboardDismissalTarget: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissalView { KeyboardDismissalView() }
    func updateUIView(_ uiView: KeyboardDismissalView, context: Context) {}
    static func dismantleUIView(_ uiView: KeyboardDismissalView, coordinator: ()) { uiView.detach() }
}
private final class KeyboardDismissalView: UIView, UIGestureRecognizerDelegate {
    private weak var attachedWindow: UIWindow?
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard attachedWindow !== window else { return }
        detach()
        if let window { window.addGestureRecognizer(tap); attachedWindow = window }
    }
    func detach() { attachedWindow?.removeGestureRecognizer(tap); attachedWindow = nil }
    @objc private func dismissKeyboard() { attachedWindow?.endEditing(true) }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window = attachedWindow, bounds.contains(convert(touch.location(in: window), from: window)) else { return false }
        var target = touch.view
        while let view = target {
            if view is UITextField || view is UITextView { return false }
            target = view.superview
        }
        return true
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
extension View {
    func dismissKeyboardOnOutsideTap() -> some View { background(KeyboardDismissalTarget()) }
}
