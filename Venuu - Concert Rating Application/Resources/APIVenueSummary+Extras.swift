import Foundation

// Lightweight convenience so the rest of the app doesn't keep unwrapping optionals.
extension SetlistAPI.APIVenueSummary {
    /// City name ("" if missing)
    var cityName: String { city?.name ?? "" }

    /// Two-letter state/region code if present ("" if missing)
    var stateCode: String { city?.stateCode ?? "" }

    /// Same as stateCode, provided for UI text (kept to match previous usage)
    var stateText: String { stateCode }
}
