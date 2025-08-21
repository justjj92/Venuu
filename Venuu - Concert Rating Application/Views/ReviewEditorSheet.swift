import SwiftUI

struct ReviewEditorSheet: View {
    let venueId: Int64
    let existing: CloudStore.VenueReviewRead?

    @Environment(\.dismiss) private var dismiss

    @State private var parking: Int
    @State private var staff: Int
    @State private var food: Int
    @State private var sound: Int
    @State private var access: Int?
    @State private var comment: String

    init(venueId: Int64, existing: CloudStore.VenueReviewRead?) {
        self.venueId = venueId
        self.existing = existing
        _parking = State(initialValue: existing?.parking ?? 0)
        _staff   = State(initialValue: existing?.staff   ?? 0)
        _food    = State(initialValue: existing?.food    ?? 0)
        _sound   = State(initialValue: existing?.sound   ?? 0)
        _access  = State(initialValue: existing?.access)
        _comment = State(initialValue: existing?.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ratings (0–5)") {
                    Stepper("Parking: \(parking)", value: $parking, in: 0...5)
                    Stepper("Staff: \(staff)",     value: $staff,   in: 0...5)
                    Stepper("Food: \(food)",       value: $food,    in: 0...5)
                    Stepper("Sound: \(sound)",     value: $sound,   in: 0...5)
                    Stepper("Accessibility: \(access ?? 0)",
                            onIncrement: { access = min((access ?? 0)+1, 5) },
                            onDecrement: { access = max((access ?? 0)-1, 0) })
                }
                Section("Comment (optional)") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 120)
                }
                if let existing {
                    Section {
                        Button("Delete my review", role: .destructive) {
                            Task {
                                try? await CloudStore.shared.deleteMyVenueReview(id: existing.id)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Leave a Review" : "Edit Your Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await CloudStore.shared.submitVenueReview(
                                venueId: venueId,
                                parking: parking, staff: staff, food: food, sound: sound,
                                access: access, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            dismiss()
                        }
                    }.bold()
                }
            }
        }
    }
}
