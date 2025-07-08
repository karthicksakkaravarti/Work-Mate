//
//  UserPreferences.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import Foundation
import CoreData

// MARK: - UserPreferences Extension

@objc(UserPreferences)
public class UserPreferences: NSManagedObject {
    
}

extension UserPreferences {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var microBreakInterval: Int32
    @NSManaged public var microBreakDuration: Int32
    @NSManaged public var regularBreakInterval: Int32
    @NSManaged public var regularBreakDuration: Int32
    @NSManaged public var overlayType: String?
    @NSManaged public var workStartTime: Date?
    @NSManaged public var workEndTime: Date?
    @NSManaged public var enableSmartScheduling: Bool
    @NSManaged public var blacklistedApps: [String]?
    @NSManaged public var soundEnabled: Bool
    @NSManaged public var selectedSoundtrack: String?
    @NSManaged public var lastModified: Date?

}

// MARK: - Convenience Methods

extension UserPreferences {
    
    /// Computed property for overlay type enum
    var overlayTypeEnum: OverlayType {
        switch overlayType?.lowercased() {
        case "full":
            return .fullScreen
        case "partial":
            return .partial
        case "notification":
            return .notification
        default:
            return .partial
        }
    }
    
    /// Computed property for work hours as formatted string
    var workHoursFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        guard let start = workStartTime,
              let end = workEndTime else {
            return "9:00 AM - 5:00 PM"
        }
        
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    /// Computed property for micro break interval in minutes
    var microBreakIntervalMinutes: Int {
        return Int(microBreakInterval)
    }
    
    /// Computed property for regular break interval in minutes
    var regularBreakIntervalMinutes: Int {
        return Int(regularBreakInterval)
    }
    
    /// Computed property for micro break duration in seconds
    var microBreakDurationSeconds: Int {
        return Int(microBreakDuration)
    }
    
    /// Computed property for regular break duration in seconds  
    var regularBreakDurationSeconds: Int {
        return Int(regularBreakDuration)
    }
    
    /// Check if the current time is within work hours
    var isWithinWorkHours: Bool {
        guard let startTime = workStartTime,
              let endTime = workEndTime else {
            return true // If no work hours set, assume always working
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        guard let currentHour = currentTime.hour,
              let currentMinute = currentTime.minute,
              let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else {
            return true
        }
        
        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        if endMinutes > startMinutes {
            // Same day (e.g., 9 AM to 5 PM)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight (e.g., 10 PM to 6 AM)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
    
    /// Get the list of blacklisted apps, ensuring it's never nil
    var safeBlacklistedApps: [String] {
        return blacklistedApps ?? []
    }
    
    /// Add an app to the blacklist
    func addBlacklistedApp(_ bundleId: String) {
        var apps = safeBlacklistedApps
        if !apps.contains(bundleId) {
            apps.append(bundleId)
            blacklistedApps = apps
            lastModified = Date()
        }
    }
    
    /// Remove an app from the blacklist
    func removeBlacklistedApp(_ bundleId: String) {
        var apps = safeBlacklistedApps
        if let index = apps.firstIndex(of: bundleId) {
            apps.remove(at: index)
            blacklistedApps = apps
            lastModified = Date()
        }
    }
    
    /// Check if an app is blacklisted
    func isAppBlacklisted(_ bundleId: String) -> Bool {
        return safeBlacklistedApps.contains(bundleId)
    }
    
    /// Update work hours
    func setWorkHours(start: Date, end: Date) {
        workStartTime = start
        workEndTime = end
        lastModified = Date()
    }
    
    /// Update break intervals
    func updateBreakIntervals(microInterval: Int32, regularInterval: Int32) {
        microBreakInterval = microInterval
        regularBreakInterval = regularInterval
        lastModified = Date()
    }
    
    /// Update break durations
    func updateBreakDurations(microDuration: Int32, regularDuration: Int32) {
        microBreakDuration = microDuration
        regularBreakDuration = regularDuration
        lastModified = Date()
    }
    
    /// Reset to default values
    func resetToDefaults() {
        microBreakInterval = 10 // 10 minutes
        microBreakDuration = 30 // 30 seconds
        regularBreakInterval = 60 // 60 minutes
        regularBreakDuration = 300 // 5 minutes
        overlayType = OverlayType.partial.rawValue
        enableSmartScheduling = true
        soundEnabled = true
        selectedSoundtrack = nil
        blacklistedApps = []
        
        // Set default work hours (9 AM to 5 PM)
        let calendar = Calendar.current
        let now = Date()
        workStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)
        workEndTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)
        
        lastModified = Date()
    }
    
    /// Create default user preferences
    static func createDefault(context: NSManagedObjectContext) -> UserPreferences {
        let preferences = UserPreferences(context: context)
        preferences.id = UUID()
        preferences.resetToDefaults()
        
        return preferences
    }
    
    /// Get or create the singleton user preferences
    static func shared(context: NSManagedObjectContext) -> UserPreferences {
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("Error fetching user preferences: \(error)")
        }
        
        // Create new preferences if none exist
        return createDefault(context: context)
    }
    
    /// Export preferences as dictionary
    func exportAsDictionary() -> [String: Any] {
        return [
            "microBreakInterval": microBreakInterval,
            "microBreakDuration": microBreakDuration,
            "regularBreakInterval": regularBreakInterval,
            "regularBreakDuration": regularBreakDuration,
            "overlayType": overlayType ?? "partial",
            "enableSmartScheduling": enableSmartScheduling,
            "soundEnabled": soundEnabled,
            "selectedSoundtrack": selectedSoundtrack ?? "",
            "blacklistedApps": safeBlacklistedApps,
            "workStartTime": workStartTime?.timeIntervalSince1970 ?? 0,
            "workEndTime": workEndTime?.timeIntervalSince1970 ?? 0
        ]
    }
    
    /// Import preferences from dictionary
    func importFromDictionary(_ data: [String: Any]) {
        microBreakInterval = Int32(data["microBreakInterval"] as? Int ?? 10)
        microBreakDuration = Int32(data["microBreakDuration"] as? Int ?? 30)
        regularBreakInterval = Int32(data["regularBreakInterval"] as? Int ?? 60)
        regularBreakDuration = Int32(data["regularBreakDuration"] as? Int ?? 300)
        overlayType = data["overlayType"] as? String ?? "partial"
        enableSmartScheduling = data["enableSmartScheduling"] as? Bool ?? true
        soundEnabled = data["soundEnabled"] as? Bool ?? true
        selectedSoundtrack = data["selectedSoundtrack"] as? String
        blacklistedApps = data["blacklistedApps"] as? [String] ?? []
        
        if let startTimeInterval = data["workStartTime"] as? TimeInterval, startTimeInterval > 0 {
            workStartTime = Date(timeIntervalSince1970: startTimeInterval)
        }
        
        if let endTimeInterval = data["workEndTime"] as? TimeInterval, endTimeInterval > 0 {
            workEndTime = Date(timeIntervalSince1970: endTimeInterval)
        }
        
        lastModified = Date()
    }
}

// MARK: - Supporting Enums

enum OverlayType: String, CaseIterable {
    case fullScreen = "full"
    case partial = "partial"
    case notification = "notification"
    
    var displayName: String {
        switch self {
        case .fullScreen:
            return "Full Screen"
        case .partial:
            return "Partial Overlay"
        case .notification:
            return "Notification Only"
        }
    }
    
    var description: String {
        switch self {
        case .fullScreen:
            return "Dims the entire screen during breaks"
        case .partial:
            return "Shows a semi-transparent overlay"
        case .notification:
            return "Shows only a notification banner"
        }
    }
} 