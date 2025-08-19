// CloudStore.swift
import Foundation
import Supabase
import SwiftData

// MARK: - DB Row Models

/// Cached setlist row we keep in Supabase so user saves can FK to it.
struct SetlistRow: Codable, Identifiable {
    let id: String
    let artist_name: String
    let venue_name: String?
    let city: String?
    let country: String?
    let event_date: String?      // "yyyy-MM-dd" UTC
    let songs: [String]
    let attribution_url: String?
}

/// Row we write when a user saves a concert
struct UserSetlistWrite: Encodable {
    let user_id: UUID
    let setlist_id: String
    let attended_on: String?     // "yyyy-MM-dd"
}

/// Row we write when posting/updating a review (1 per user+setlist)
struct ReviewWrite: Encodable {
    let user_id: UUID
    let setlist_id: String
    let rating: Int
    let comment: String?
}

/// Reviews you READ from a view (joined w/ profiles, setlists, vote counts)
struct ReviewRead: Decodable, Identifiable {
    let id: Int64
    let setlist_id: String
    let rating: Int
    let comment: String?
    let created_at: String?
    let updated_at: String?
    let user_id: UUID
    let username: String?

    // From joined setlists (optional)
    let artist_name: String?
    let venue_name: String?
    let event_date: String?      // "yyyy-MM-dd"

    // Vote aggregates from the view
    let up_votes: Int?
    let down_votes: Int?
}

// MARK: - Profiles

struct ProfileRead: Decodable {
    let id: UUID
    let username: String?
    let display_name: String?
    let avatar_url: String?
    let email: String?
}

struct ProfileUpsert: Encodable {
    let id: UUID
    let username: String?
    let display_name: String?
    let avatar_url: String?
    let email: String?            // store email for username→email sign-in
}

// MARK: - Cloud Store

/// NOTE: Not @MainActor globally. We only hop to main when touching SwiftData.
final class CloudStore {
    static let shared = CloudStore()
    private init() {}

    // yyyy-MM-dd (UTC) for DB
    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        return f
    }()

    private func currentUserID() async -> UUID? {
        (try? await supa.auth.session)?.user.id
    }

    // MARK: - Setlists (cache)

    /// Ensure a setlist row exists in Supabase (from API)
    func upsertSetlist(from api: APISetlist) async throws {
        let parsedDate = api.eventDate.flatMap { SetlistAPI.shared.eventDateFormatter.date(from: $0) }
        let ymdString = parsedDate.map { CloudStore.ymd.string(from: $0) }

        let row = SetlistRow(
            id: api.id,
            artist_name: api.artist.name,
            venue_name: api.venue?.name,
            city: api.venue?.city?.name,
            country: api.venue?.city?.country?.name ?? api.venue?.city?.country?.code,
            event_date: ymdString,
            songs: api.sets?.set?.flatMap { $0.song?.compactMap { $0.name } ?? [] } ?? [],
            attribution_url: api.url
        )

        _ = try await supa.database
            .from("setlists")
            .upsert(row, onConflict: "id")
            .execute()
    }

    /// Ensure a setlist row exists in Supabase (from local SwiftData model)
    func upsertSetlist(fromLocal s: SavedConcert) async throws {
        let ymdString = s.eventDate.map { CloudStore.ymd.string(from: $0) }
        let row = SetlistRow(
            id: s.setlistId,
            artist_name: s.artistName,
            venue_name: s.venueName,
            city: s.city,
            country: s.country,
            event_date: ymdString,
            songs: s.songs,
            attribution_url: s.attributionURL
        )
        _ = try await supa.database
            .from("setlists")
            .upsert(row, onConflict: "id")
            .execute()
    }

    /// Save to the current user (requires auth; RLS uses auth.uid())
    func saveToUser(setlistId: String, attendedOn: Date? = nil) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in to save concerts."])
        }
        let ymdString = attendedOn.map { CloudStore.ymd.string(from: $0) }
        let write = UserSetlistWrite(user_id: session.user.id, setlist_id: setlistId, attended_on: ymdString)
        _ = try await supa.database
            .from("user_setlists")
            .upsert(write, onConflict: "user_id,setlist_id")
            .execute()
    }

    /// NEW: Unsave (remove from the current user's saved list)
    func unsaveFromUser(setlistId: String) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in."])
        }
        _ = try await supa.database
            .from("user_setlists")
            .delete()
            .eq("user_id", value: session.user.id)   // important for RLS
            .eq("setlist_id", value: setlistId)
            .execute()
    }

    /// Load my saved setlists (joined with setlists table)
    func loadMySavedSetlists() async throws -> [SetlistRow] {
        struct Wrapper: Decodable { let setlists: SetlistRow }
        let joined: [Wrapper] = try await supa.database
            .from("user_setlists")
            .select("setlists(id,artist_name,venue_name,city,country,event_date,songs,attribution_url)")
            .order("created_at", ascending: false)
            .execute()
            .value
        return joined.map { $0.setlists }
    }

    // MARK: - Reviews

    /// Submit or update my review (one per user per setlist).
    func submitReview(setlistId: String, rating: Int, comment: String?) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in to post a review."])
        }
        let write = ReviewWrite(
            user_id: session.user.id,
            setlist_id: setlistId,
            rating: rating,
            comment: comment
        )
        _ = try await supa.database
            .from("reviews")
            .upsert(write, onConflict: "user_id,setlist_id")
            .execute()
    }

    /// Convenience: make sure the setlist row exists first.
    func submitReview(setlist: APISetlist, rating: Int, comment: String?) async throws {
        try await upsertSetlist(from: setlist)
        try await submitReview(setlistId: setlist.id, rating: rating, comment: comment)
    }

    /// Load public reviews for a setlist
    func loadReviews(setlistId: String) async throws -> [ReviewRead] {
        try await supa.database
            .from("reviews_with_users")
            .select()
            .eq("setlist_id", value: setlistId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Load my reviews
    func loadMyReviews() async throws -> [ReviewRead] {
        guard let session = try? await supa.auth.session else { return [] }
        return try await supa.database
            .from("reviews_with_users")
            .select()
            .eq("user_id", value: session.user.id)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// FIXED: Delete a review I own (include user_id filter for RLS)
    func deleteMyReview(id: Int64) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in."])
        }
        _ = try await supa.database
            .from("reviews")
            .delete()
            .eq("id", value: Int(id))               // iOS Int is 64-bit; safe for BIGINT ids
            .eq("user_id", value: session.user.id)  // important for RLS
            .execute()
    }

    /// Delete many (loop for SDK-compat simplicity)
    func deleteMyReviews(ids: [Int64]) async throws {
        for rid in ids { try await deleteMyReview(id: rid) }
    }

    // MARK: - Votes

    /// Load my votes for a list of review IDs: returns [review_id: value]
    func loadMyVotes(reviewIDs: [Int64]) async throws -> [Int64: Int] {
        guard let session = try? await supa.auth.session else { return [:] }
        let idsInt = reviewIDs.map(Int.init)
        if idsInt.isEmpty { return [:] }

        struct Row: Decodable { let review_id: Int; let value: Int }
        let rows: [Row] = try await supa.database
            .from("review_votes")
            .select("review_id,value")
            .eq("user_id", value: session.user.id)
            .in("review_id", value: idsInt)
            .execute()
            .value

        var out: [Int64: Int] = [:]
        for r in rows { out[Int64(r.review_id)] = r.value }
        return out
    }

    /// Upsert my vote (-1 or 1)
    func upsertVote(reviewId: Int64, value: Int) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in to vote."])
        }
        struct VoteWrite: Encodable {
            let review_id: Int
            let user_id: UUID
            let value: Int
        }
        let write = VoteWrite(review_id: Int(reviewId), user_id: session.user.id, value: value)
        _ = try await supa.database
            .from("review_votes")
            .upsert(write, onConflict: "user_id,review_id")
            .execute()
    }

    /// Clear my vote on a review
    func clearVote(reviewId: Int64) async throws {
        guard let session = try? await supa.auth.session else { return }
        _ = try await supa.database
            .from("review_votes")
            .delete()
            .eq("user_id", value: session.user.id)
            .eq("review_id", value: Int(reviewId))
            .execute()
    }

    // MARK: - Profiles / Username login helpers

    func fetchMyProfile() async throws -> ProfileRead? {
        guard let session = try? await supa.auth.session else { return nil }
        let rows: [ProfileRead] = try await supa.database
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Upsert profile (we also store email for username→email login)
    func upsertMyProfile(username: String?,
                         displayName: String?,
                         avatarURL: String? = nil,
                         email: String? = nil) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in."])
        }
        let row = ProfileUpsert(id: session.user.id,
                                username: username,
                                display_name: displayName,
                                avatar_url: avatarURL,
                                email: email)
        _ = try await supa.database
            .from("profiles")
            .upsert(row)
            .execute()
    }

    /// username → email (for “sign in with username”)
    func emailForUsername(_ username: String) async throws -> String? {
        struct Row: Decodable { let email: String? }
        let rows: [Row] = try await supa.database
            .from("profiles")
            .select("email")
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        return rows.first?.email
    }

    /// Returns true if the username **does not exist**
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await supa.database
            .from("profiles")
            .select("id")
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        return rows.isEmpty
    }

    /// After we obtain a session (or after confirmation), seed/update profile
    func upsertProfileAfterAuth(username: String?) async throws {
        guard let session = try? await supa.auth.session else { return }
        try await upsertMyProfile(username: username,
                                  displayName: nil,
                                  avatarURL: nil,
                                  email: session.user.email)
    }

    /// Remove all user-owned records (votes → reviews → saves → profile).
    func deleteMyContent() async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in."])
        }
        let uid = session.user.id

        // Order matters if you don’t have ON DELETE CASCADE.
        _ = try await supa.database.from("review_votes").delete()
            .eq("user_id", value: uid).execute()

        _ = try await supa.database.from("reviews").delete()
            .eq("user_id", value: uid).execute()

        _ = try await supa.database.from("user_setlists").delete()
            .eq("user_id", value: uid).execute()

        _ = try await supa.database.from("profiles").delete()
            .eq("id", value: uid).execute()
    }

    // MARK: - Offline-first sync (SCOPED TO CURRENT USER)

    /// Pull this user’s cloud saved setlists into local SwiftData (merge; no deletes).
    @MainActor
    func mergeCloudSavedIntoLocal(using ctx: ModelContext) async {
        guard let uid = await currentUserID() else { return }
        do {
            let remote = try await loadMySavedSetlists()
            for r in remote {
                let pred = #Predicate<SavedConcert> { $0.setlistId == r.id && $0.ownerUserId == uid }
                let existing = try ctx.fetch(FetchDescriptor<SavedConcert>(predicate: pred))
                if let local = existing.first {
                    local.artistName = r.artist_name
                    local.venueName = r.venue_name
                    local.city = r.city
                    local.country = r.country
                    local.attributionURL = r.attribution_url
                    local.songs = r.songs
                    local.eventDate = r.event_date.flatMap { CloudStore.ymd.date(from: $0) }
                    local.pendingCloudSave = false
                    local.lastCloudSyncAt = Date()
                    local.ownerUserId = uid
                } else {
                    let model = SavedConcert(
                        setlistId: r.id,
                        artistName: r.artist_name,
                        venueName: r.venue_name,
                        city: r.city,
                        country: r.country,
                        eventDate: r.event_date.flatMap { CloudStore.ymd.date(from: $0) },
                        songs: r.songs,
                        attributionURL: r.attribution_url,
                        pendingCloudSave: false,
                        ownerUserId: uid
                    )
                    model.lastCloudSyncAt = Date()
                    ctx.insert(model)
                }
            }
            try? ctx.save()
        } catch {
            print("mergeCloudSavedIntoLocal error:", error)
        }
    }

    /// Push any pending local saves up to cloud (if logged in); only for this user.
    @MainActor
    func syncPendingSaves(using ctx: ModelContext) async {
        guard let uid = await currentUserID() else { return }
        do {
            let pred = #Predicate<SavedConcert> { $0.pendingCloudSave == true && $0.ownerUserId == uid }
            let pending = try ctx.fetch(FetchDescriptor<SavedConcert>(predicate: pred))
            for s in pending {
                do {
                    try await upsertSetlist(fromLocal: s)
                    try await saveToUser(setlistId: s.setlistId, attendedOn: s.eventDate)
                    s.pendingCloudSave = false
                    s.lastCloudSyncAt = Date()
                    s.ownerUserId = uid
                } catch {
                    print("sync single save failed:", error)
                }
            }
            try? ctx.save()
        } catch {
            print("syncPendingSaves fetch failed:", error)
        }
    }

    // MARK: - Local removal helpers

    /// Remove a single local SavedConcert for a given user.
    @MainActor
    func removeLocalSaved(setlistId: String, ownerUserId: UUID?, using ctx: ModelContext) {
        do {
            let pred = #Predicate<SavedConcert> { $0.setlistId == setlistId && $0.ownerUserId == ownerUserId }
            if let obj = try ctx.fetch(FetchDescriptor<SavedConcert>(predicate: pred)).first {
                ctx.delete(obj)
                try? ctx.save()
            }
        } catch {
            print("removeLocalSaved error:", error)
        }
    }

    /// Convenience: unsave in cloud then remove locally.
    func unsaveEverywhere(setlistId: String, using ctx: ModelContext) async throws {
        let uid = await currentUserID()
        try await unsaveFromUser(setlistId: setlistId)
        await MainActor.run { self.removeLocalSaved(setlistId: setlistId, ownerUserId: uid, using: ctx) }
    }
}
