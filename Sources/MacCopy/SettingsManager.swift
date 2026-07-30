import Foundation

@MainActor
class SettingsManager {
    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard
    
    var historyLimit: Int {
        get {
            let limit = defaults.integer(forKey: "historyLimit")
            return limit == 0 ? 50 : limit
        }
        set { defaults.set(newValue, forKey: "historyLimit") }
    }
    
    var hotkeyCode: UInt32 {
        get {
            if defaults.object(forKey: "hotkeyCode") == nil { return 8 } // Default 'C'
            return UInt32(defaults.integer(forKey: "hotkeyCode"))
        }
        set { defaults.set(newValue, forKey: "hotkeyCode") }
    }
    
    var hotkeyModifiers: UInt32 {
        get {
            if defaults.object(forKey: "hotkeyModifiers") == nil { return 768 } // Default cmd + shift
            return UInt32(defaults.integer(forKey: "hotkeyModifiers"))
        }
        set { defaults.set(newValue, forKey: "hotkeyModifiers") }
    }
    
    var hotkeyString: String {
        get { defaults.string(forKey: "hotkeyString") ?? "⌘⇧C" }
        set { defaults.set(newValue, forKey: "hotkeyString") }
    }
}
