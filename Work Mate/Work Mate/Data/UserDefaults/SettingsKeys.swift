//
//  SettingsKeys.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation

/// UserDefaults keys and default values for Work Mate settings
enum SettingsKeys {
    
    // MARK: - Break Timing Settings
    static let microBreakInterval = "microBreakInterval"
    static let microBreakDuration = "microBreakDuration"
    static let regularBreakInterval = "regularBreakInterval"
    static let regularBreakDuration = "regularBreakDuration"
    
    // MARK: - Break Behavior Settings
    static let overlayType = "overlayType"
    static let enableSmartScheduling = "enableSmartScheduling"
    static let pauseOnInactivity = "pauseOnInactivity"
    static let inactivityThreshold = "inactivityThreshold"
    
    // MARK: - Audio Settings
    static let soundEnabled = "soundEnabled"
    static let selectedSoundtrack = "selectedSoundtrack"
    static let soundVolume = "soundVolume"
    
    // MARK: - Work Schedule Settings
    static let workStartHour = "workStartHour"
    static let workStartMinute = "workStartMinute"
    static let workEndHour = "workEndHour"
    static let workEndMinute = "workEndMinute"
    static let enableWorkSchedule = "enableWorkSchedule"
    static let skipWeekendsEnabled = "skipWeekendsEnabled"
    
    // MARK: - Privacy and Analytics
    static let analyticsEnabled = "analyticsEnabled"
    static let crashReportingEnabled = "crashReportingEnabled"
    static let dataRetentionDays = "dataRetentionDays"
    
    // MARK: - App Behavior
    static let launchAtLogin = "launchAtLogin"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let enableNotifications = "enableNotifications"
    static let notificationSound = "notificationSound"
    
    // MARK: - Advanced Settings
    static let debugModeEnabled = "debugModeEnabled"
    static let logLevel = "logLevel"
    static let blacklistedApps = "blacklistedApps"
    
    // MARK: - First Launch and Onboarding
    static let isFirstLaunch = "isFirstLaunch"
    static let onboardingCompleted = "onboardingCompleted"
    static let permissionsRequested = "permissionsRequested"
    
    // MARK: - iCloud Sync (Optional)
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    static let lastSyncDate = "lastSyncDate"
}

/// Default values for all settings
enum SettingsDefaults {
    
    // MARK: - Break Timing Defaults (in minutes for intervals, seconds for durations)
    static let microBreakInterval: Int = 10        // 10 minutes
    static let microBreakDuration: Int = 30        // 30 seconds
    static let regularBreakInterval: Int = 60      // 60 minutes (1 hour)
    static let regularBreakDuration: Int = 300     // 300 seconds (5 minutes)
    
    // MARK: - Break Behavior Defaults
    static let overlayType: String = "partial"     // "full", "partial", "notification"
    static let enableSmartScheduling: Bool = true
    static let pauseOnInactivity: Bool = true
    static let inactivityThreshold: Int = 120      // 2 minutes in seconds
    
    // MARK: - Audio Defaults
    static let soundEnabled: Bool = true
    static let selectedSoundtrack: String = "default"
    static let soundVolume: Double = 0.5           // 50% volume
    
    // MARK: - Work Schedule Defaults (9 AM to 5 PM)
    static let workStartHour: Int = 9
    static let workStartMinute: Int = 0
    static let workEndHour: Int = 17              // 5 PM in 24-hour format
    static let workEndMinute: Int = 0
    static let enableWorkSchedule: Bool = false    // Disabled by default
    static let skipWeekendsEnabled: Bool = true
    
    // MARK: - Privacy and Analytics Defaults
    static let analyticsEnabled: Bool = true       // User can opt-out
    static let crashReportingEnabled: Bool = true
    static let dataRetentionDays: Int = 90        // 3 months
    
    // MARK: - App Behavior Defaults
    static let launchAtLogin: Bool = false
    static let showMenuBarIcon: Bool = true
    static let enableNotifications: Bool = true
    static let notificationSound: String = "default"
    
    // MARK: - Advanced Defaults
    static let debugModeEnabled: Bool = false
    static let logLevel: String = "info"          // "debug", "info", "warning", "error"
    static let blacklistedApps: [String] = []     // Empty array by default
    
    // MARK: - First Launch Defaults
    static let isFirstLaunch: Bool = true
    static let onboardingCompleted: Bool = false
    static let permissionsRequested: Bool = false
    
    // MARK: - iCloud Sync Defaults
    static let iCloudSyncEnabled: Bool = false
    static let lastSyncDate: Date? = nil
}

/// Break overlay types
enum OverlayType: String, CaseIterable {
    case full = "full"           // Full screen overlay
    case partial = "partial"     // Partial screen overlay
    case notification = "notification" // System notification only
    
    var displayName: String {
        switch self {
        case .full:
            return "Full Screen"
        case .partial:
            return "Partial Overlay"
        case .notification:
            return "Notification Only"
        }
    }
    
    var description: String {
        switch self {
        case .full:
            return "Covers the entire screen to ensure you take a break"
        case .partial:
            return "Shows a gentle overlay that doesn't block everything"
        case .notification:
            return "Shows only a system notification"
        }
    }
}

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case `default` = "default"
    case chime = "chime"
    case bell = "bell"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .chime:
            return "Chime"
        case .bell:
            return "Bell"
        case .none:
            return "None"
        }
    }
} 