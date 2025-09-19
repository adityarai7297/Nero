import Foundation

struct Config {
    // MARK: - API Keys
    static let deepseekAPIKey: String = {
        // Try to get from Info.plist first (most secure)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "$(DEEPSEEK_API_KEY)" {
            return plistKey
        }
        
        // Try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] {
            return envKey
        }
        
        // Fallback to hardcoded key (REPLACE THIS WITH YOUR ACTUAL API KEY)
        return "sk-7b3bb28157654ced84c5906317e3fc0c"
    }()
    
    // MARK: - Supabase
    static let supabaseURLString: String = {
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
           !plistURL.isEmpty, plistURL != "$(SUPABASE_URL)" {
            return plistURL
        }
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"], !envURL.isEmpty {
            return envURL
        }
        return ""
    }()
    
    static let supabaseAnonKey: String = {
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
           !plistKey.isEmpty, plistKey != "$(SUPABASE_ANON_KEY)" {
            return plistKey
        }
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !envKey.isEmpty {
            return envKey
        }
        return ""
    }()
    
    static func isSupabaseConfigured() -> Bool {
        guard let url = URL(string: supabaseURLString), !supabaseAnonKey.isEmpty else { return false }
        // Basic URL host check
        return url.scheme?.hasPrefix("http") == true && (url.host?.isEmpty == false)
    }
    
    // MARK: - API Endpoints
    static let deepseekBaseURL = "https://api.deepseek.com"
    
    // MARK: - Configuration Validation
    static func validateConfiguration() -> Bool {
        return !deepseekAPIKey.isEmpty && 
               deepseekAPIKey != "sk-your-actual-deepseek-api-key-goes-here" &&
               deepseekAPIKey != "$(DEEPSEEK_API_KEY)" &&
               deepseekAPIKey.hasPrefix("sk-")
    }
    
    // MARK: - Debug Helper
    static func debugConfiguration() {
        print("🔑 DeepSeek API Key Status:")
        print("   - Key exists: \(!deepseekAPIKey.isEmpty)")
        print("   - Key format valid: \(deepseekAPIKey.hasPrefix("sk-"))")
        print("   - Key length: \(deepseekAPIKey.count)")
        print("   - Configuration valid: \(validateConfiguration())")
        
        if !validateConfiguration() {
            print("❌ Please set your DeepSeek API key in Config.swift")
        } else {
            print("✅ DeepSeek API key configured correctly")
        }
        
        // Supabase debug without leaking secrets
        let urlStatus = URL(string: supabaseURLString) != nil && !supabaseURLString.isEmpty
        print("🔐 Supabase Config Status:")
        print("   - URL configured: \(urlStatus)")
        print("   - Anon key present: \(!supabaseAnonKey.isEmpty)")
        print("   - Supabase configured: \(isSupabaseConfigured())")
    }
} 