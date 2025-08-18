import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject var auth: AuthVM
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if auth.isSignedIn, let p = auth.profile {
                        GlassCard {
                            // Header
                            HStack(spacing: 14) {
                                MusicAvatar(initial: (p.display_name ?? p.username)?.first.map { String($0) })
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.display_name ?? p.username ?? "User")
                                        .font(.title3).bold()
                                    if let u = p.username {
                                        Text("@\(u)").foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                        Text("Signed in")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                                Spacer()
                            }

                            Divider().padding(.vertical, 8)

                            // Rows
                            NavigationLink {
                                // IMPORTANT: pass the current user id to scope local data
                                MyConcertsView()
                            } label: {
                                row(title: "Saved Concerts", systemImage: "bookmark.fill")
                            }

                            NavigationLink {
                                MyReviewsView()
                            } label: {
                                row(title: "My Reviews", systemImage: "text.bubble.fill")
                            }

                            NavigationLink {
                                SettingsView()
                                    .environmentObject(auth)
                            } label: {
                                row(title: "Settings", systemImage: "gearshape.fill")
                            }

                            Button(role: .destructive) {
                                Task { await auth.signOut() }
                            } label: {
                                row(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right.fill")
                                    .foregroundStyle(.red)
                            }
                        }

                    } else {
                        // Guest state
                        GlassCard {
                            BlueWideButton(title: "Sign In / Sign Up") { showLogin = true }
                            Text("Sign in to save concerts & leave reviews.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet()
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Auto-close the login sheet when a session appears
        .onChange(of: auth.session) { _, newValue in
            if newValue != nil { showLogin = false }
        }
    }

    // MARK: - Row helper (uniform style)
    private func row(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 22)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .font(.body)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
