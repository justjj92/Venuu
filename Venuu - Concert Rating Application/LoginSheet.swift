// LoginSheet.swift
import SwiftUI

struct LoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthVM

    enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signIn

    // Sign In
    @State private var identifier = ""  // email OR username
    @State private var password = ""
    @State private var signingIn = false

    // Sign Up
    @State private var email = ""
    @State private var username = ""
    @State private var password1 = ""
    @State private var password2 = ""
    @State private var creating = false
    @State private var usernameOK: Bool? = nil   // nil = unknown

    // UX
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    Picker("", selection: $mode) {
                        Text("Sign In").tag(Mode.signIn)
                        Text("Sign Up").tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    Group { if mode == .signIn { signInForm } else { signUpForm } }
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    if let err = error {
                        Text(err).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Sign in to save concerts & leave reviews.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .onChange(of: username) { _, newValue in
                guard mode == .signUp else { return }
                Task { await checkUsername(newValue) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.blue.opacity(0.2), .indigo.opacity(0.12)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
            VStack(spacing: 6) {
                Text("Venuu")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Music • Memories • Reviews")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Forms

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormCaption(text: "Email or username")
            TextField("you@email.com or @user", text: $identifier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .glassField()
                .focused($focused)

            FormCaption(text: "Password")
            SecureField("Your password", text: $password)
                .glassField()
                .focused($focused)

            BlueWideButton(title: "Sign In",
                           isBusy: signingIn,
                           isDisabled: identifier.isEmpty || password.isEmpty) {
                Task { await signIn() }
            }
            .padding(.top, 6)
        }
    }

    private var signUpForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormCaption(text: "Email")
            TextField("you@email.com", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .glassField()
                .focused($focused)

            FormCaption(text: "Username (required)")
            HStack(spacing: 8) {
                TextField("@username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .glassField()
                    .focused($focused)
                if let ok = usernameOK {
                    Image(systemName: ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(ok ? .green : .red)
                        .font(.title3)
                        .padding(.trailing, 2)
                }
            }

            FormCaption(text: "Password (min 6)")
            SecureField("Enter password", text: $password1)
                .glassField()
                .focused($focused)

            FormCaption(text: "Confirm password")
            SecureField("Re-enter password", text: $password2)
                .glassField()
                .focused($focused)

            BlueWideButton(
                title: "Create Account",
                isBusy: creating,
                isDisabled: !canCreate
            ) {
                Task { await signUp() }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Actions

    private var canCreate: Bool {
        !email.isEmpty &&
        !username.isEmpty &&
        password1.count >= 6 &&
        password1 == password2 &&
        (usernameOK ?? false)
    }

    private func signIn() async {
        error = nil; signingIn = true
        defer { signingIn = false }
        do {
            try await auth.signIn(emailOrUsername: identifier, password: password)
            if auth.session != nil { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signUp() async {
        error = nil; creating = true
        defer { creating = false }
        guard canCreate else { return }

        do {
            try await auth.signUp(email: email, password: password1, username: username)
            // seed profile with username/email (ignore error if it races with RLS)
            try? await CloudStore.shared.upsertProfileAfterAuth(username: username)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func checkUsername(_ name: String) async {
        guard !name.isEmpty else { usernameOK = nil; return }
        do {
            usernameOK = try await CloudStore.shared.isUsernameAvailable(name)
        } catch {
            usernameOK = nil
        }
    }
}

// MARK: - Small helpers (renamed to avoid collisions)

private struct FormCaption: View {
    let text: String
    var body: some View { Text(text).font(.footnote).foregroundStyle(.secondary) }
}

private extension View {
    func glassField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
    }
}
