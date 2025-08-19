import SwiftUI

struct AccountSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var error: String?
    let existing: ProfileRead?

    init(existing: ProfileRead?) {
        self.existing = existing
        _username = State(initialValue: existing?.username ?? "")
        _displayName = State(initialValue: existing?.display_name ?? "")
    }

    var body: some View {
        Form {
            Section("Public profile") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                TextField("Name (optional)", text: $displayName)
            }

            Section {
                Button("Save") {
                    Task {
                        do {
                            try await CloudStore.shared.upsertMyProfile(username: username.isEmpty ? nil : username,
                                                                        displayName: displayName.isEmpty ? nil : displayName)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }

            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Update Profile")
    }
}
