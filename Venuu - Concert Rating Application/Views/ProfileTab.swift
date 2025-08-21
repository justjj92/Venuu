import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject var auth: AuthVM
    @State private var showLogin = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if auth.isSignedIn, let p = auth.profile {
                            // Signed-in card
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
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 2)
                                    }
                                    Spacer()
                                }

                                Divider().padding(.vertical, 10)

                                // Actions with gradient icons
                                VStack(spacing: 0) {
                                    NavigationLink {
                                        MyConcertsHost().environmentObject(auth)
                                    } label: {
                                        ProfileRow(title: "Saved Concerts", systemImage: "bookmark.fill")
                                    }
                                    Divider().opacity(0.06)

                                    NavigationLink {
                                        MyReviewsView()
                                    } label: {
                                        ProfileRow(title: "My Concert Reviews", systemImage: "music.mic")
                                    }
                                    Divider().opacity(0.06)

                                    NavigationLink {
                                        MyVenuesReviews()
                                    } label: {
                                        ProfileRow(title: "My Venue Reviews", systemImage: "building.columns.fill")
                                    }
                                    Divider().opacity(0.06)

                                    NavigationLink {
                                        SettingsView().environmentObject(auth)
                                    } label: {
                                        ProfileRow(title: "Settings", systemImage: "gearshape.fill")
                                    }
                                }
                                .padding(.top, 2)
                            }

                            // breathing room so floating sign-out doesn’t overlap
                            Spacer(minLength: 80)
                        } else {
                            // Signed-out card
                            GlassCard {
                                BlueWideButton(title: "Sign In / Sign Up") { showLogin = true }
                                Text("Sign in to save concerts, review venues, and more.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100) // leave room for the floating button
                }

                // Floating Sign Out — ONLY on ProfileTab root
                if auth.isSignedIn {
                    VStack {
                        Spacer()
                        Button {
                            showSignOutConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                            )
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                        }
                        .padding(.bottom, 22)   // a little above the bottom
                        .padding(.horizontal, 20)
                    }
                    .allowsHitTesting(true)
                }
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet().environmentObject(auth)
        }
        .alert("Are you sure you want to log out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                Task { await auth.signOut() }
            }
        }
        // App-wide styling
        .scrollContentBackground(.hidden)
        .background(Theme.appBackground)
        .toolbarBackground(Theme.gradient, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Gradient Icon Row (restores your icon chips)

private struct ProfileRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.gradient.opacity(0.20))
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.gradient)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(width: 30, height: 30)

            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }
}

// Wraps MyConcertsView (no-arg) so ProfileTab stays simple.
private struct MyConcertsHost: View {
    @EnvironmentObject var auth: AuthVM
    var body: some View {
        MyConcertsView()
    }
}
