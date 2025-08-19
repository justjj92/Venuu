import SwiftUI

// MARK: - Buttons

struct BlueWideButton: View {
    var title: String
    var isBusy: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            guard !isBusy && !isDisabled else { return }
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .indigo],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .blue.opacity(0.22), radius: 18, x: 0, y: 10)

                HStack(spacing: 8) {
                    if isBusy { ProgressView().controlSize(.small).tint(.white) }
                    Text(title).font(.headline).foregroundStyle(.white)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
            }
            .opacity((isBusy || isDisabled) ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isBusy)
    }
}

// MARK: - Containers

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
        )
    }
}

// MARK: - Inputs

struct RoundedField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func roundedField() -> some View { modifier(RoundedField()) }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}

// MARK: - Bits

struct MusicAvatar: View {
    var initial: String? = nil
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .blue.opacity(0.25), radius: 10, x: 0, y: 6)
            if let ch = initial, !ch.isEmpty {
                Text(String(ch.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.white)
                    .font(.system(size: 26, weight: .semibold))
            }
        }
        .frame(width: 64, height: 64)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }
}
