import Foundation
import Supabase

let supabase: SupabaseClient = {
  guard Config.isSupabaseConfigured(),
        let url = URL(string: Config.supabaseURLString) else {
    fatalError("Supabase is not configured. Set SupabaseURL and SupabaseAnonKey in Info.plist or environment.")
  }
  return SupabaseClient(
    supabaseURL: url,
    supabaseKey: Config.supabaseAnonKey,
    options: SupabaseClientOptions(
      auth: .init(
        redirectToURL: URL(string: "gamified.fit.Cerro://auth-callback")
      )
    )
  )
}()