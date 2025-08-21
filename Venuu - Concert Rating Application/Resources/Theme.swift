import SwiftUI

enum Theme {
    // Brand gradient (works in light/dark)
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.42, blue: 0.96),  // blue
            Color(red: 0.33, green: 0.22, blue: 0.95)   // indigo
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Backgrounds
    static let appBackground = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.secondarySystemBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardFill = Color(.secondarySystemBackground)
    static let hairline  = Color.primary.opacity(0.06)

    // Radii & shadows
    static let cornerLg: CGFloat = 16
    static let cornerMd: CGFloat = 12
    static let shadow = Shadow(radius: 14, y: 6, opacity: 0.08)

    struct Shadow {
        let radius: CGFloat
        let y: CGFloat
        let opacity: Double
    }
}

// MARK: - Common modifiers

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.cornerLg).fill(Theme.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerLg)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(Theme.shadow.opacity),
                    radius: Theme.shadow.radius, x: 0, y: Theme.shadow.y)
    }
}

extension View {
    func card() -> some View { modifier(Card()) }
}

// MARK: - Buttons

struct GradientButtonStyle: ButtonStyle {
    var isWide: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: isWide ? .infinity : nil)
            .background(Theme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.12),
                    radius: configuration.isPressed ? 8 : 14, x: 0, y: 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// A convenience wrapper for your existing CTA
//struct BlueWideButton: View {
//    let title: String
//    let action: () -> Void
//    var body: some View {
//        Button(title, action: action).buttonStyle(GradientButtonStyle())
//    }
//}

// MARK: - Search Field

struct RoundedIconField: View {
    let system: String
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($focused)
                .onSubmit { onSubmit() }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMd)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMd)
                .strokeBorder(focused ? .clear : Theme.hairline, lineWidth: 1)
        )
        .overlay(
            // glow when focused
            RoundedRectangle(cornerRadius: Theme.cornerMd)
                .stroke(Theme.gradient, lineWidth: focused ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.15), value: focused)
    }
}
