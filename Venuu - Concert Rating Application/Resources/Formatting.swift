import Foundation

extension DateFormatter {
    /// Output for the UI: MM-dd-yyyy
    static let mdyOut: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd-yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Input from DB/view rows like "yyyy-MM-dd"
    static let ymdIn: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
