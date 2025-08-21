// SettingsView.swift
import SwiftUI
import Supabase   // for supa.auth.update(user:)

struct SettingsView: View {
    @EnvironmentObject var auth: AuthVM
    @AppStorage("useDarkMode") private var useDarkMode = false

    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Account Card
                    GlassCard {
                        Text("Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            NavigationLink {
                                UpdatePasswordView()
                            } label: {
                                SettingRow(title: "Update Password", systemImage: "key.fill")
                            }
                            Divider().opacity(0.06)

                            NavigationLink {
                                UpdateProfileView()
                            } label: {
                                SettingRow(title: "Update Profile", systemImage: "person.crop.circle.fill")
                            }
                        }
                        .padding(.top, 2)
                    }

                    // MARK: Appearance Card
                    GlassCard {
                        Text("Appearance")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.gradient.opacity(0.20))
                                Image(systemName: "moon.fill")
                                    .foregroundStyle(Theme.gradient)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(width: 30, height: 30)

                            Toggle("Dark Mode", isOn: $useDarkMode)
                                .tint(Theme.gradient)
                                .onChange(of: useDarkMode) { _, newVal in
                                    // apply immediately app-wide
                                    UIApplication.shared.connectedScenes
                                        .compactMap { $0 as? UIWindowScene }
                                        .flatMap { $0.windows }
                                        .forEach { $0.overrideUserInterfaceStyle = newVal ? .dark : .unspecified }
                                }
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: Danger Zone Card
                    GlassCard {
                        Text("Danger Zone")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 10) {
                            Text("This removes your reviews, votes, saved concerts and profile. Your auth account (email) remains.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete My Account Data")
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
        // Confirm delete flow
        .confirmationDialog(
            "Delete your data?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            if deleting {
                Button("Deleting…") {}.disabled(true)
            } else {
                Button("Delete My Data", role: .destructive) {
                    Task { await deleteMyData() }
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            Text("This removes your reviews, votes, saved concerts and profile. Your auth account (email) remains.")
        }
        .alert("Delete failed", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        // Global chrome
        .scrollContentBackground(.hidden)
        .background(Theme.appBackground)
        .toolbarBackground(Theme.gradient, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func deleteMyData() async {
        guard !deleting else { return }
        deleting = true; defer { deleting = false }
        do {
            try await CloudStore.shared.deleteMyContent()
            await auth.signOut()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Polished Row (matches Profile style)

private struct SettingRow: View {
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

// MARK: - Update Password

struct UpdatePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPass1 = ""
    @State private var newPass2 = ""
    @State private var changing = false
    @State private var error: String?
    @State private var success: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Change Password")
                        .font(.headline)

                    SecureField("New password (min 6)", text: $newPass1)
                        .textContentType(.newPassword)

                    SecureField("Confirm new password", text: $newPass2)
                        .textContentType(.newPassword)

                    BlueWideButton(
                        title: "Update Password",
                        isBusy: changing,
                        isDisabled: !canChange
                    ) { Task { await changePassword() } }

                    if let s = success { Text(s).font(.footnote).foregroundStyle(.green) }
                    if let e = error { Text(e).font(.footnote).foregroundStyle(.red) }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.appBackground)
        .navigationTitle("Update Password")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.appBackground)              // behind list
        .toolbarBackground(Theme.gradient, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var canChange: Bool {
        newPass1.count >= 6 && newPass1 == newPass2
    }

    private func changePassword() async {
        guard canChange else { return }
        error = nil; success = nil
        changing = true; defer { changing = false }
        do {
            try await supa.auth.update(user: .init(password: newPass1))
            newPass1 = ""; newPass2 = ""
            success = "Password updated."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Update Profile

struct UpdateProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var username = ""
    @State private var originalUsername = ""

    @State private var loading = true
    @State private var saving = false
    @State private var usernameOK: Bool? = nil
    @State private var error: String?
    @State private var success: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Profile")
                        .font(.headline)

                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.words)

                    HStack(spacing: 8) {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let ok = usernameOK {
                            Image(systemName: ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundStyle(ok ? .green : .red)
                        }
                    }

                    BlueWideButton(
                        title: "Save",
                        isBusy: saving,
                        isDisabled: !canSave
                    ) { Task { await save() } }

                    if let s = success { Text(s).font(.footnote).foregroundStyle(.green) }
                    if let e = error { Text(e).font(.footnote).foregroundStyle(.red) }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.appBackground)
        .navigationTitle("Update Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task { await load() }
        .onChange(of: username) { _, newVal in
            Task { await validateUsername(newVal) }
        }
    }

    private var canSave: Bool {
        !username.isEmpty && (usernameOK ?? true)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            if let p = try await CloudStore.shared.fetchMyProfile() {
                displayName = p.display_name ?? ""
                username = p.username ?? ""
                originalUsername = username
                await validateUsername(username)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func validateUsername(_ name: String) async {
        guard !name.isEmpty else { usernameOK = nil; return }
        do {
            if name == originalUsername {
                usernameOK = true; return
            }
            usernameOK = try await CloudStore.shared.isUsernameAvailable(name)
        } catch {
            usernameOK = nil
        }
    }

    private func save() async {
        guard canSave else { return }
        error = nil; success = nil
        saving = true; defer { saving = false }
        do {
            try await CloudStore.shared.upsertMyProfile(
                username: username,
                displayName: displayName,
                avatarURL: nil
            )
            success = "Profile updated."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
