import SwiftUI
import Supabase

/// Blue gradient + Sign In / Sign Up with:
/// - Sign in using email OR username
/// - Forgot password (reset email)
/// - Forgot username (look up by email)
struct LoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthVM

    enum Mode: String, CaseIterable { case signIn = "Sign In", signUp = "Sign Up" }

    @State private var mode: Mode = .signIn

    // Sign in
    @State private var emailOrUsername: String = ""
    @State private var password: String = ""

    // Sign up
    @State private var signupEmail: String = ""
    @State private var signupUsername: String = ""
    @State private var signupPassword: String = ""

    // UI state
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    // Sheets
    @State private var showForgotPassword = false
    @State private var showForgotUsername = false

    var body: some View {
        VStack(spacing: 0) {
            Header()

            // Switcher
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 16) {
                    if mode == .signIn { signInForm } else { signUpForm }

                    if let err = errorMessage {
                        Text(err).foregroundStyle(.red).font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    if let msg = infoMessage {
                        Text(msg).foregroundStyle(.secondary).font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
                .presentationDetents([.fraction(0.38), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showForgotUsername) {
            ForgotUsernameSheet()
                .presentationDetents([.fraction(0.38), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Forms

    private var signInForm: some View {
        VStack(spacing: 14) {
            IconField(system: "at.circle.fill",
                      placeholder: "Email or Username",
                      text: $emailOrUsername)

            SecureIconField(system: "lock.fill",
                            placeholder: "Password",
                            text: $password)

            BlueWideButton(title: busy ? "Signing In…" : "Sign In",
                           isBusy: busy,
                           isDisabled: busy || emailOrUsername.isEmpty || password.isEmpty) {
                Task { await signIn() }
            }

            HStack(spacing: 18) {
                Button("Forgot password?") { showForgotPassword = true }
                    .buttonStyle(.plain)
                    .font(.footnote)
                Button("Forgot username?") { showForgotUsername = true }
                    .buttonStyle(.plain)
                    .font(.footnote)
            }
            .padding(.top, 6)

            Text("By signing in, you can save concerts and leave reviews.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var signUpForm: some View {
        VStack(spacing: 14) {
            IconField(system: "envelope.fill",
                      placeholder: "Email",
                      text: $signupEmail)
                .textInputAutocapitalization(.never)

            IconField(system: "person.fill",
                      placeholder: "Username (required)",
                      text: $signupUsername)
                .textInputAutocapitalization(.never)

            SecureIconField(system: "lock.fill",
                            placeholder: "Password (min 6 chars)",
                            text: $signupPassword)

            BlueWideButton(title: busy ? "Creating Account…" : "Create Account",
                           isBusy: busy,
                           isDisabled: busy || signupEmail.isEmpty || signupUsername.isEmpty || signupPassword.count < 6) {
                Task { await signUp() }
            }

            Text("Usernames are public and must be unique.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Actions

    private func signIn() async {
        guard !busy else { return }
        errorMessage = nil; infoMessage = nil; busy = true
        defer { busy = false }

        do {
            // Convert username → email if needed
            var email = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            if !email.contains("@") {
                if let e = try await CloudStore.shared.emailForUsername(email) {
                    email = e
                } else {
                    throw NSError(domain: "auth", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "No account found for that username."])
                }
            }

            _ = try await supa.auth.signIn(email: email, password: password)

            // Optional: refresh profile in AuthVM (if you maintain it there)
            await auth.refreshProfile()

            infoMessage = "Signed in!"
            // Dismiss shortly after a small delay for a nicer feel
            try? await Task.sleep(nanoseconds: 450_000_000)
            dismiss()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func signUp() async {
        guard !busy else { return }
        errorMessage = nil; infoMessage = nil; busy = true
        defer { busy = false }

        do {
            // Enforce unique username
            let available = try await CloudStore.shared.isUsernameAvailable(signupUsername)
            guard available else {
                throw NSError(domain: "auth", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "That username is taken. Try another one."])
            }

            _ = try await supa.auth.signUp(email: signupEmail, password: signupPassword)

            // Seed profile (also stores email to support username sign-in)
            try await CloudStore.shared.upsertProfileAfterAuth(username: signupUsername)

            await auth.refreshProfile()

            infoMessage = "Account created!"
            try? await Task.sleep(nanoseconds: 450_000_000)
            dismiss()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Forgot Password

private struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var busy = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("We’ll email you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                IconField(system: "envelope.fill", placeholder: "Your email", text: $email)
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await send() }
                } label: {
                    Text(busy ? "Sending…" : "Send Reset Email")
                        .frame(minWidth: 0) // keep it natural size
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || email.isEmpty)
                
                if sent {
                    Text("Check your inbox for the reset link.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                if let err = errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func send() async {
        guard !busy else { return }
        busy = true; errorMessage = nil; sent = false
        defer { busy = false }
        do {
            // If you have an app/deep-link, pass redirectTo:. Otherwise nil uses your Supabase auth settings.
            try await supa.auth.resetPasswordForEmail(email, redirectTo: nil)
            sent = true
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Forgot Username

private struct ForgotUsernameSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var busy = false
    @State private var usernames: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Enter your account email. We’ll look up any usernames connected to it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                IconField(system: "envelope.fill", placeholder: "Your email", text: $email)
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await lookup() }
                } label: {
                    Text(busy ? "Looking up…" : "Find Username")
                        .frame(minWidth: 0)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || email.isEmpty)

                if !usernames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Found username\(usernames.count > 1 ? "s" : ""):")
                            .font(.subheadline.bold())
                        ForEach(usernames, id: \.self) { u in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                Text("@\(u)")
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                if let err = errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Forgot Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func lookup() async {
        guard !busy else { return }
        busy = true; errorMessage = nil; usernames = []
        defer { busy = false }

        do {
            struct Row: Decodable { let username: String? }
            let rows: [Row] = try await supa.database
                .from("profiles")
                .select("username")
                .eq("email", value: email)
                .execute()
                .value

            let list = rows.compactMap { $0.username }.filter { !$0.isEmpty }
            if list.isEmpty {
                errorMessage = "No usernames found for that email."
            } else {
                usernames = list
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - UI Bits (local to this file)

private struct Header: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Venuu")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 8)
            Text("Sign in to save concerts & leave reviews")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(colors: [Color.blue, Color.indigo],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct IconField: View {
    let system: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: system).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }
}

private struct SecureIconField: View {
    let system: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: system).foregroundStyle(.secondary)
            SecureField(placeholder, text: $text)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }
}
