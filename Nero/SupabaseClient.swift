import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://zohjfuyehgzxscdtqsoo.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvaGpmdXllaGd6eHNjZHRxc29vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2ODA0MDYsImV4cCI6MjA2MzI1NjQwNn0.o3RiiCvjC6jIcmFPSbPy_anglAaRyzajNV5DkJnZQls",
  options: SupabaseClientOptions(
    auth: .init(
      redirectToURL: URL(string: "gamified.fit.Cerro://auth-callback")
    )
  )
) 