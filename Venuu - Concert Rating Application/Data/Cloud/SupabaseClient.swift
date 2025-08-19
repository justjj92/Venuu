import Supabase
import Foundation

enum Env {
    // Paste your values from the Supabase dashboard:
    static let url = URL(string: "https://wgspofknwmdixsinyzul.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indnc3BvZmtud21kaXhzaW55enVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMjY0NzMsImV4cCI6MjA3MDcwMjQ3M30.kQFwSqUgJXmYmdYJXegNqZXmKHPTxLds9w1mBoo4G7w"
}

// Global client you can use anywhere
let supa = SupabaseClient(supabaseURL: Env.url, supabaseKey: Env.anonKey)
