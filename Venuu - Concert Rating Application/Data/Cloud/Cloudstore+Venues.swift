import Foundation
import Supabase

// MARK: - Helpers that decode numbers even if they come back as strings
private extension KeyedDecodingContainer {
    func lossyInt64(forKey key: Key) throws -> Int64 {
        if let v = try? decode(Int64.self, forKey: key) { return v }
        if let v = try? decode(Int.self,  forKey: key)  { return Int64(v) }
        if let s = try? decode(String.self, forKey: key),
           let v = Int64(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return v }
        throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key],
                                                debugDescription: "Expected int/int64/string-int"))
    }
    func lossyInt(forKey key: Key) throws -> Int {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let s = try? decode(String.self, forKey: key),
           let v = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return v }
        throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key],
                                                debugDescription: "Expected int/string-int"))
    }
    /// Accept String / UUID / Int / Int64 and surface a String (used for user_id)
    func lossyString(forKey key: Key) -> String? {
        if let s  = try? decode(String.self, forKey: key) { return s }
        if let u  = try? decode(UUID.self,   forKey: key) { return u.uuidString }
        if let i  = try? decode(Int.self,    forKey: key) { return String(i) }
        if let i6 = try? decode(Int64.self,  forKey: key) { return String(i6) }
        return nil
    }
}

extension CloudStore {

    // MARK: - Venues (table-backed row)
    struct VenueRow: Decodable, Identifiable, Hashable {
        let id: Int64
        let name: String
        let city: String?
        let state: String?
        let avg_rating: Double?   // nil when coming straight from `venues`
        let reviews_count: Int?

        enum CodingKeys: String, CodingKey { case id, name, city, state, avg_rating, reviews_count }

        init(id: Int64, name: String, city: String?, state: String?, avg_rating: Double?, reviews_count: Int?) {
            self.id = id; self.name = name; self.city = city; self.state = state
            self.avg_rating = avg_rating; self.reviews_count = reviews_count
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let id   = (try? c.lossyInt64(forKey: .id)) ?? 0
            let name = (try? c.decode(String.self, forKey: .name)) ?? "Venue"
            let city = try? c.decodeIfPresent(String.self, forKey: .city)
            let st   = try? c.decodeIfPresent(String.self, forKey: .state)
            let avg  = try? c.decodeIfPresent(Double.self, forKey: .avg_rating)
            let rc   = try? c.lossyInt(forKey: .reviews_count)
            self.init(id: id, name: name, city: city, state: st, avg_rating: avg, reviews_count: rc)
        }
    }

    private struct VenueWrite: Encodable {
        let name: String
        let city: String?
        let state: String?
    }

    // Create if missing, else return existing (table-only)
    func fetchOrCreateVenue(from api: SetlistAPI.APIVenueSummary) async throws -> VenueRow {
        let name  = api.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let city  = (api.city?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let state = (api.city?.stateCode ?? api.city?.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cityArg: String?  = city.isEmpty  ? nil : city
        let stateArg: String? = state.isEmpty ? nil : state

        var q = supa.database
            .from("venues")
            .select("id,name,city,state", head: false, count: nil)
            .filter("name", operator: "eq", value: name)
        if let c = cityArg  { q = q.filter("city",  operator: "eq", value: c) }
        if let s = stateArg { q = q.filter("state", operator: "eq", value: s) }

        let found: [VenueRow] = try await q.limit(1).execute().value
        if let v = found.first { return v }

        let write = VenueWrite(name: name, city: cityArg, state: stateArg)
        let inserted: [VenueRow] = try await supa.database
            .from("venues")
            .insert(write)
            .select("id,name,city,state")
            .execute()
            .value
        guard let v = inserted.first else {
            throw NSError(domain: "venues", code: -1, userInfo: [NSLocalizedDescriptionKey: "Insert returned no rows"])
        }
        return v
    }

    // MARK: - Reviews (view-backed; type-stable)

    struct VenueReviewRead: Decodable, Identifiable, Hashable {
        let id: Int64
        let venue_id: Int64
        let parking: Int
        let staff: Int
        let food: Int
        let sound: Int
        let access: Int?
        let comment: String?
        let created_at: String?
        let updated_at: String?      // might be nil / not selected by the view
        let user_id: String          // ← from view as TEXT (safe)

        let username: String?
        let display_name: String?
        let venue_name: String?
        let venue_city: String?
        let venue_state: String?

        enum CodingKeys: String, CodingKey {
            case id, venue_id, parking, staff, food, sound, access, comment, created_at, updated_at, user_id
            case username, display_name, venue_name, venue_city, venue_state
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id        = try c.lossyInt64(forKey: .id)
            venue_id  = try c.lossyInt64(forKey: .venue_id)
            parking   = (try? c.lossyInt(forKey: .parking)) ?? 0
            staff     = (try? c.lossyInt(forKey: .staff))   ?? 0
            food      = (try? c.lossyInt(forKey: .food))    ?? 0
            sound     = (try? c.lossyInt(forKey: .sound))   ?? 0
            access    = (try? c.lossyInt(forKey: .access))
            comment   = try? c.decodeIfPresent(String.self, forKey: .comment)
            created_at = try? c.decodeIfPresent(String.self, forKey: .created_at)
            updated_at = try? c.decodeIfPresent(String.self, forKey: .updated_at)
            user_id   = c.lossyString(forKey: .user_id) ?? ""
            username  = try? c.decodeIfPresent(String.self, forKey: .username)
            display_name = try? c.decodeIfPresent(String.self, forKey: .display_name)
            venue_name  = try? c.decodeIfPresent(String.self, forKey: .venue_name)
            venue_city  = try? c.decodeIfPresent(String.self, forKey: .venue_city)
            venue_state = try? c.decodeIfPresent(String.self, forKey: .venue_state)
        }
    }

    // Read all reviews for a venue (via RPC; includes username/display_name)
    func loadVenueReviews(venueId: Int64) async throws -> [VenueReviewRead] {
        struct Params: Encodable { let p_venue_id: Int64 }
        return try await supa.database
            .rpc("venue_reviews_for_venue", params: Params(p_venue_id: venueId))
            .execute()
            .value
    }

    // Read my reviews for Profile tab (from the view, so venue_* fields are present)
    func loadMyVenueReviews() async throws -> [VenueReviewRead] {
        // Server identifies the caller via auth.uid() inside the SQL; no params needed.
        try await supa.database
            .rpc("my_venue_reviews")
            .execute()
            .value
    }


    // Create OR Update my review (upsert on unique (user_id, venue_id))
    func submitVenueReview(
        venueId: Int64,
        parking: Int, staff: Int, food: Int, sound: Int,
        access: Int?, comment: String?
    ) async throws {
        guard let session = try? await supa.auth.session else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in."])
        }
        struct Write: Encodable {
            let user_id: UUID, venue_id: Int64
            let parking: Int, staff: Int, food: Int, sound: Int
            let access: Int?, comment: String?
        }
        let w = Write(user_id: session.user.id, venue_id: venueId,
                      parking: parking, staff: staff, food: food, sound: sound,
                      access: access, comment: comment)
        _ = try await supa.database
            .from("venue_reviews")
            .upsert(w, onConflict: "user_id,venue_id")
            .execute()
    }

    // Delete my review by id
    func deleteMyVenueReview(id: Int64) async throws {
        _ = try await supa.database
            .from("venue_reviews")
            .delete()
            .filter("id", operator: "eq", value: String(id))
            .execute()
    }


    // MARK: - Venue lookups (table only)
    func findVenue(name: String, city: String?, state: String?) async throws -> VenueRow? {
        var q = supa.database
            .from("venues")
            .select("id,name,city,state", head: false, count: nil)
            .filter("name", operator: "eq", value: name)
        if let city,  !city.isEmpty  { q = q.filter("city",  operator: "eq", value: city) }
        if let state, !state.isEmpty { q = q.filter("state", operator: "eq", value: state) }
        let rows: [VenueRow] = try await q.limit(1).execute().value
        return rows.first
    }

    func findVenueById(_ id: Int64) async throws -> VenueRow? {
        let rows: [VenueRow] = try await supa.database
            .from("venues")
            .select("id,name,city,state", head: false, count: nil)
            .filter("id", operator: "eq", value: String(id))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsertVenue(name: String, city: String?, state: String?) async throws -> VenueRow {
        let write = VenueWrite(name: name, city: city, state: state)
        let inserted: [VenueRow] = try await supa.database
            .from("venues")
            .insert(write)
            .select("id,name,city,state")
            .execute()
            .value
        guard let v = inserted.first else {
            throw NSError(domain: "venues", code: -1, userInfo: [NSLocalizedDescriptionKey: "Insert failed"])
        }
        return v
    }
}
