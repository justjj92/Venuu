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
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                                Spacer()
                            }

                            Divider().padding(.vertical, 8)

                            // Saved concerts
                            NavigationLink {
                                MyConcertsHost()         // <- no-arg host
                                    .environmentObject(auth)
                            } label: {
                                rowLabel("Saved Concerts")
                            }

                            // My concert reviews
                            NavigationLink {
                                MyReviewsView()
                            } label: {
                                rowLabel("My Concert Reviews")
                            }

                            // My venue reviews
                            NavigationLink {
                                MyVenuesReviews()
                            } label: {
                                rowLabel("My Venue Reviews")
                            }

                            // Settings
                            NavigationLink {
                                SettingsView().environmentObject(auth)
                            } label: {
                                row(title: "Settings", systemImage: "gearshape.fill")
                            }

                            // Sign out
                            Button(role: .destructive) {
                                Task { await auth.signOut() }
                            } label: {
                                HStack {
                                    Text("Sign Out")
                                    Spacer()
                                }
                            }
                        }
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
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet().environmentObject(auth)
        }
    }

    // MARK: - Row helpers

    private func row(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .font(.body)
    }

    /// Back-compat helper to match older calls (`rowLabel("…")`).
    private func rowLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .font(.body)
    }
}

// Wraps MyConcertsView (no-arg) so ProfileTab stays simple.
private struct MyConcertsHost: View {
    @EnvironmentObject var auth: AuthVM
    var body: some View {
        // Your current MyConcertsView must already scope to the signed-in user internally.
        // If you later switch back to a parameterized version, change this to:
        // MyConcertsView(ownerId: auth.session?.user.id)
        MyConcertsView()
    }
}


