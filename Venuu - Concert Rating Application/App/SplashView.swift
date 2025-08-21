import SwiftUI

/// Pulsing logo splash that matches Theme.appBackground/Theme.gradient,
/// with a large VENUU wordmark pinned to the top.
struct SplashView: View {
    @State private var scale: CGFloat = 0.86
    @State private var opacity: Double = 0.0
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            // Background
            Theme.appBackground
                .ignoresSafeArea()

            // Subtle vignette
            RadialGradient(colors: [
                Color.black.opacity(0.0),
                Color.black.opacity(0.06)
            ], center: .center, startRadius: 0, endRadius: 450)
            .ignoresSafeArea()

            // TOP — big wordmark
            VStack {
                Text("VENUU")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(Theme.gradient)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                    .padding(.top, 52)
                    .opacity(opacity)
                    .offset(y: opacity > 0 ? 0 : -12)
                Spacer()
            }
            .allowsHitTesting(false)

            // CENTER — pulsing logo + ring
            ZStack {
                // Glowing ring behind the logo
                Circle()
                    .stroke(Theme.gradient, lineWidth: glow ? 14 : 8)
                    .frame(width: glow ? 180 : 150, height: glow ? 180 : 150)
                    .opacity(0.35)
                    .blur(radius: glow ? 6 : 1)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glow)

                // Glassy chip
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Theme.gradient.opacity(0.45), lineWidth: 1)
                        )
                        .frame(width: 160, height: 160)

                    // Brand mark asset, with SF Symbol fallback
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .overlay {
                            // Fallback symbol if the asset doesn't exist
                            if UIImage(named: "AppLogo") == nil {
                                Image(systemName: "music.quarternote.3")
                                    .font(.system(size: 58, weight: .semibold))
                                    .foregroundStyle(Theme.gradient)
                            }
                        }
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                glow = true
                withAnimation(.spring(response: 0.7, dampingFraction: 0.72, blendDuration: 0.25)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 1.0
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Overlay gate — unchanged usage.
/// Show SplashView while `isActive == true`.
struct SplashGate<Content: View>: View {
    @Binding var isActive: Bool
    let content: () -> Content

    @State private var dismissing = false

    init(isActive: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._isActive = isActive
        self.content = content
    }

    var body: some View {
        ZStack {
            content()

            if isActive {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            } else if dismissing {
                Color.clear
                    .transition(.opacity)
                    .onAppear { dismissing = false }
            }
        }
        .animation(.easeInOut(duration: 1.0), value: isActive)
        .onChange(of: isActive) { _, newVal in
            if !newVal { dismissing = true }
        }
    }
}
