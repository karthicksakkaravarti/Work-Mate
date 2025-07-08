//
//  SettingsManager.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import SwiftUI
import Combine

/// Main settings manager using @AppStorage for reactive settings management
@MainActor
class SettingsManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SettingsManager()
    
    // MARK: - Break Timing Settings
    @AppStorage(SettingsKeys.microBreakInterval)
    var microBreakInterval: Int = SettingsDefaults.microBreakInterval
    
    @AppStorage(SettingsKeys.microBreakDuration)
    var microBreakDuration: Int = SettingsDefaults.microBreakDuration
    
    @AppStorage(SettingsKeys.regularBreakInterval)
    var regularBreakInterval: Int = SettingsDefaults.regularBreakInterval
    
    @AppStorage(SettingsKeys.regularBreakDuration)
    var regularBreakDuration: Int = SettingsDefaults.regularBreakDuration
    
    // MARK: - Break Behavior Settings
    @AppStorage(SettingsKeys.overlayType)
    var overlayType: String = SettingsDefaults.overlayType
    
    @AppStorage(SettingsKeys.enableSmartScheduling)
    var enableSmartScheduling: Bool = SettingsDefaults.enableSmartScheduling
    
    @AppStorage(SettingsKeys.pauseOnInactivity)
    var pauseOnInactivity: Bool = SettingsDefaults.pauseOnInactivity
    
    @AppStorage(SettingsKeys.inactivityThreshold)
    var inactivityThreshold: Int = SettingsDefaults.inactivityThreshold
    
    // MARK: - Audio Settings
    @AppStorage(SettingsKeys.soundEnabled)
    var soundEnabled: Bool = SettingsDefaults.soundEnabled
    
    @AppStorage(SettingsKeys.selectedSoundtrack)
    var selectedSoundtrack: String = SettingsDefaults.selectedSoundtrack
    
    @AppStorage(SettingsKeys.soundVolume)
    var soundVolume: Double = SettingsDefaults.soundVolume
    
    // MARK: - Work Schedule Settings
    @AppStorage(SettingsKeys.workStartHour)
    var workStartHour: Int = SettingsDefaults.workStartHour
    
    @AppStorage(SettingsKeys.workStartMinute)
    var workStartMinute: Int = SettingsDefaults.workStartMinute
    
    @AppStorage(SettingsKeys.workEndHour)
    var workEndHour: Int = SettingsDefaults.workEndHour
    
    @AppStorage(SettingsKeys.workEndMinute)
    var workEndMinute: Int = SettingsDefaults.workEndMinute
    
    @AppStorage(SettingsKeys.enableWorkSchedule)
    var enableWorkSchedule: Bool = SettingsDefaults.enableWorkSchedule
    
    @AppStorage(SettingsKeys.skipWeekendsEnabled)
    var skipWeekendsEnabled: Bool = SettingsDefaults.skipWeekendsEnabled
    
    // MARK: - Privacy and Analytics Settings
    @AppStorage(SettingsKeys.analyticsEnabled)
    var analyticsEnabled: Bool = SettingsDefaults.analyticsEnabled
    
    @AppStorage(SettingsKeys.crashReportingEnabled)
    var crashReportingEnabled: Bool = SettingsDefaults.crashReportingEnabled
    
    @AppStorage(SettingsKeys.dataRetentionDays)
    var dataRetentionDays: Int = SettingsDefaults.dataRetentionDays
    
    // MARK: - App Behavior Settings
    @AppStorage(SettingsKeys.launchAtLogin)
    var launchAtLogin: Bool = SettingsDefaults.launchAtLogin
    
    @AppStorage(SettingsKeys.showMenuBarIcon)
    var showMenuBarIcon: Bool = SettingsDefaults.showMenuBarIcon
    
    @AppStorage(SettingsKeys.enableNotifications)
    var enableNotifications: Bool = SettingsDefaults.enableNotifications
    
    @AppStorage(SettingsKeys.notificationSound)
    var notificationSound: String = SettingsDefaults.notificationSound
    
    // MARK: - Advanced Settings
    @AppStorage(SettingsKeys.debugModeEnabled)
    var debugModeEnabled: Bool = SettingsDefaults.debugModeEnabled
    
    @AppStorage(SettingsKeys.logLevel)
    var logLevel: String = SettingsDefaults.logLevel
    
    // MARK: - First Launch and Onboarding
    @AppStorage(SettingsKeys.isFirstLaunch)
    var isFirstLaunch: Bool = SettingsDefaults.isFirstLaunch
    
    @AppStorage(SettingsKeys.onboardingCompleted)
    var onboardingCompleted: Bool = SettingsDefaults.onboardingCompleted
    
    @AppStorage(SettingsKeys.permissionsRequested)
    var permissionsRequested: Bool = SettingsDefaults.permissionsRequested
    
    // MARK: - iCloud Sync Settings
    @AppStorage(SettingsKeys.iCloudSyncEnabled)
    var iCloudSyncEnabled: Bool = SettingsDefaults.iCloudSyncEnabled
    
    // MARK: - Complex Settings (using UserDefaults directly)
    var blacklistedApps: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: SettingsKeys.blacklistedApps) ?? SettingsDefaults.blacklistedApps
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SettingsKeys.blacklistedApps)
            objectWillChange.send()
        }
    }
    
    var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: SettingsKeys.lastSyncDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SettingsKeys.lastSyncDate)
            objectWillChange.send()
        }
    }
    
    // MARK: - Computed Properties
    var overlayTypeEnum: OverlayType {
        get {
            OverlayType(rawValue: overlayType) ?? .partial
        }
        set {
            overlayType = newValue.rawValue
        }
    }
    
    var notificationSoundEnum: NotificationSound {
        get {
            NotificationSound(rawValue: notificationSound) ?? .default
        }
        set {
            notificationSound = newValue.rawValue
        }
    }
    
    var workStartTime: Date {
        get {
            let calendar = Calendar.current
            var components = DateComponents()
            components.hour = workStartHour
            components.minute = workStartMinute
            return calendar.date(from: components) ?? Date()
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            workStartHour = components.hour ?? SettingsDefaults.workStartHour
            workStartMinute = components.minute ?? SettingsDefaults.workStartMinute
        }
    }
    
    var workEndTime: Date {
        get {
            let calendar = Calendar.current
            var components = DateComponents()
            components.hour = workEndHour
            components.minute = workEndMinute
            return calendar.date(from: components) ?? Date()
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            workEndHour = components.hour ?? SettingsDefaults.workEndHour
            workEndMinute = components.minute ?? SettingsDefaults.workEndMinute
        }
    }
    
    // MARK: - Validation Properties
    var isValidWorkSchedule: Bool {
        let startMinutes = workStartHour * 60 + workStartMinute
        let endMinutes = workEndHour * 60 + workEndMinute
        return endMinutes > startMinutes
    }
    
    var isValidBreakIntervals: Bool {
        return microBreakInterval > 0 && 
               regularBreakInterval > 0 && 
               microBreakDuration > 0 && 
               regularBreakDuration > 0 &&
               microBreakInterval <= regularBreakInterval
    }
    
    // MARK: - Private Init
    private init() {
        // Perform any initial setup or validation
        validateAndFixSettings()
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to their default values
    func resetToDefaults() {
        microBreakInterval = SettingsDefaults.microBreakInterval
        microBreakDuration = SettingsDefaults.microBreakDuration
        regularBreakInterval = SettingsDefaults.regularBreakInterval
        regularBreakDuration = SettingsDefaults.regularBreakDuration
        overlayType = SettingsDefaults.overlayType
        enableSmartScheduling = SettingsDefaults.enableSmartScheduling
        pauseOnInactivity = SettingsDefaults.pauseOnInactivity
        inactivityThreshold = SettingsDefaults.inactivityThreshold
        soundEnabled = SettingsDefaults.soundEnabled
        selectedSoundtrack = SettingsDefaults.selectedSoundtrack
        soundVolume = SettingsDefaults.soundVolume
        workStartHour = SettingsDefaults.workStartHour
        workStartMinute = SettingsDefaults.workStartMinute
        workEndHour = SettingsDefaults.workEndHour
        workEndMinute = SettingsDefaults.workEndMinute
        enableWorkSchedule = SettingsDefaults.enableWorkSchedule
        skipWeekendsEnabled = SettingsDefaults.skipWeekendsEnabled
        analyticsEnabled = SettingsDefaults.analyticsEnabled
        crashReportingEnabled = SettingsDefaults.crashReportingEnabled
        dataRetentionDays = SettingsDefaults.dataRetentionDays
        launchAtLogin = SettingsDefaults.launchAtLogin
        showMenuBarIcon = SettingsDefaults.showMenuBarIcon
        enableNotifications = SettingsDefaults.enableNotifications
        notificationSound = SettingsDefaults.notificationSound
        debugModeEnabled = SettingsDefaults.debugModeEnabled
        logLevel = SettingsDefaults.logLevel
        blacklistedApps = SettingsDefaults.blacklistedApps
        iCloudSyncEnabled = SettingsDefaults.iCloudSyncEnabled
        lastSyncDate = SettingsDefaults.lastSyncDate
    }
    
    /// Export current settings as a dictionary
    func exportSettings() -> [String: Any] {
        return [
            SettingsKeys.microBreakInterval: microBreakInterval,
            SettingsKeys.microBreakDuration: microBreakDuration,
            SettingsKeys.regularBreakInterval: regularBreakInterval,
            SettingsKeys.regularBreakDuration: regularBreakDuration,
            SettingsKeys.overlayType: overlayType,
            SettingsKeys.enableSmartScheduling: enableSmartScheduling,
            SettingsKeys.pauseOnInactivity: pauseOnInactivity,
            SettingsKeys.inactivityThreshold: inactivityThreshold,
            SettingsKeys.soundEnabled: soundEnabled,
            SettingsKeys.selectedSoundtrack: selectedSoundtrack,
            SettingsKeys.soundVolume: soundVolume,
            SettingsKeys.workStartHour: workStartHour,
            SettingsKeys.workStartMinute: workStartMinute,
            SettingsKeys.workEndHour: workEndHour,
            SettingsKeys.workEndMinute: workEndMinute,
            SettingsKeys.enableWorkSchedule: enableWorkSchedule,
            SettingsKeys.skipWeekendsEnabled: skipWeekendsEnabled,
            SettingsKeys.analyticsEnabled: analyticsEnabled,
            SettingsKeys.crashReportingEnabled: crashReportingEnabled,
            SettingsKeys.dataRetentionDays: dataRetentionDays,
            SettingsKeys.launchAtLogin: launchAtLogin,
            SettingsKeys.showMenuBarIcon: showMenuBarIcon,
            SettingsKeys.enableNotifications: enableNotifications,
            SettingsKeys.notificationSound: notificationSound,
            SettingsKeys.debugModeEnabled: debugModeEnabled,
            SettingsKeys.logLevel: logLevel,
            SettingsKeys.blacklistedApps: blacklistedApps,
            SettingsKeys.iCloudSyncEnabled: iCloudSyncEnabled
        ]
    }
    
    /// Import settings from a dictionary
    func importSettings(from data: [String: Any]) {
        if let value = data[SettingsKeys.microBreakInterval] as? Int {
            microBreakInterval = value
        }
        if let value = data[SettingsKeys.microBreakDuration] as? Int {
            microBreakDuration = value
        }
        if let value = data[SettingsKeys.regularBreakInterval] as? Int {
            regularBreakInterval = value
        }
        if let value = data[SettingsKeys.regularBreakDuration] as? Int {
            regularBreakDuration = value
        }
        if let value = data[SettingsKeys.overlayType] as? String {
            overlayType = value
        }
        if let value = data[SettingsKeys.enableSmartScheduling] as? Bool {
            enableSmartScheduling = value
        }
        if let value = data[SettingsKeys.pauseOnInactivity] as? Bool {
            pauseOnInactivity = value
        }
        if let value = data[SettingsKeys.inactivityThreshold] as? Int {
            inactivityThreshold = value
        }
        if let value = data[SettingsKeys.soundEnabled] as? Bool {
            soundEnabled = value
        }
        if let value = data[SettingsKeys.selectedSoundtrack] as? String {
            selectedSoundtrack = value
        }
        if let value = data[SettingsKeys.soundVolume] as? Double {
            soundVolume = value
        }
        if let value = data[SettingsKeys.workStartHour] as? Int {
            workStartHour = value
        }
        if let value = data[SettingsKeys.workStartMinute] as? Int {
            workStartMinute = value
        }
        if let value = data[SettingsKeys.workEndHour] as? Int {
            workEndHour = value
        }
        if let value = data[SettingsKeys.workEndMinute] as? Int {
            workEndMinute = value
        }
        if let value = data[SettingsKeys.enableWorkSchedule] as? Bool {
            enableWorkSchedule = value
        }
        if let value = data[SettingsKeys.skipWeekendsEnabled] as? Bool {
            skipWeekendsEnabled = value
        }
        if let value = data[SettingsKeys.analyticsEnabled] as? Bool {
            analyticsEnabled = value
        }
        if let value = data[SettingsKeys.crashReportingEnabled] as? Bool {
            crashReportingEnabled = value
        }
        if let value = data[SettingsKeys.dataRetentionDays] as? Int {
            dataRetentionDays = value
        }
        if let value = data[SettingsKeys.launchAtLogin] as? Bool {
            launchAtLogin = value
        }
        if let value = data[SettingsKeys.showMenuBarIcon] as? Bool {
            showMenuBarIcon = value
        }
        if let value = data[SettingsKeys.enableNotifications] as? Bool {
            enableNotifications = value
        }
        if let value = data[SettingsKeys.notificationSound] as? String {
            notificationSound = value
        }
        if let value = data[SettingsKeys.debugModeEnabled] as? Bool {
            debugModeEnabled = value
        }
        if let value = data[SettingsKeys.logLevel] as? String {
            logLevel = value
        }
        if let value = data[SettingsKeys.blacklistedApps] as? [String] {
            blacklistedApps = value
        }
        if let value = data[SettingsKeys.iCloudSyncEnabled] as? Bool {
            iCloudSyncEnabled = value
        }
        
        validateAndFixSettings()
    }
    
    /// Add an app to the blacklist
    func addBlacklistedApp(_ bundleIdentifier: String) {
        var apps = blacklistedApps
        if !apps.contains(bundleIdentifier) {
            apps.append(bundleIdentifier)
            blacklistedApps = apps
        }
    }
    
    /// Remove an app from the blacklist
    func removeBlacklistedApp(_ bundleIdentifier: String) {
        blacklistedApps = blacklistedApps.filter { $0 != bundleIdentifier }
    }
    
    /// Check if an app is blacklisted
    func isAppBlacklisted(_ bundleIdentifier: String) -> Bool {
        return blacklistedApps.contains(bundleIdentifier)
    }
    
    /// Check if the current time falls within work hours
    func isWithinWorkHours(_ date: Date = Date()) -> Bool {
        guard enableWorkSchedule else { return true }
        
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        
        // Check if it's weekend and weekends are skipped
        if skipWeekendsEnabled {
            let weekday = currentComponents.weekday ?? 1
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                return false
            }
        }
        
        let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        let startMinutes = workStartHour * 60 + workStartMinute
        let endMinutes = workEndHour * 60 + workEndMinute
        
        return currentMinutes >= startMinutes && currentMinutes <= endMinutes
    }
    
    // MARK: - Private Methods
    
    private func validateAndFixSettings() {
        // Ensure valid break intervals
        if microBreakInterval <= 0 {
            microBreakInterval = SettingsDefaults.microBreakInterval
        }
        if regularBreakInterval <= 0 {
            regularBreakInterval = SettingsDefaults.regularBreakInterval
        }
        if microBreakDuration <= 0 {
            microBreakDuration = SettingsDefaults.microBreakDuration
        }
        if regularBreakDuration <= 0 {
            regularBreakDuration = SettingsDefaults.regularBreakDuration
        }
        
        // Ensure micro break interval is not greater than regular break interval
        if microBreakInterval >= regularBreakInterval {
            microBreakInterval = min(regularBreakInterval - 1, SettingsDefaults.microBreakInterval)
        }
        
        // Ensure valid work hours
        if workStartHour < 0 || workStartHour > 23 {
            workStartHour = SettingsDefaults.workStartHour
        }
        if workEndHour < 0 || workEndHour > 23 {
            workEndHour = SettingsDefaults.workEndHour
        }
        if workStartMinute < 0 || workStartMinute > 59 {
            workStartMinute = SettingsDefaults.workStartMinute
        }
        if workEndMinute < 0 || workEndMinute > 59 {
            workEndMinute = SettingsDefaults.workEndMinute
        }
        
        // Ensure valid overlay type
        if OverlayType(rawValue: overlayType) == nil {
            overlayType = SettingsDefaults.overlayType
        }
        
        // Ensure valid notification sound
        if NotificationSound(rawValue: notificationSound) == nil {
            notificationSound = SettingsDefaults.notificationSound
        }
        
        // Ensure valid sound volume
        if soundVolume < 0.0 || soundVolume > 1.0 {
            soundVolume = SettingsDefaults.soundVolume
        }
        
        // Ensure valid inactivity threshold
        if inactivityThreshold < 30 { // Minimum 30 seconds
            inactivityThreshold = max(30, SettingsDefaults.inactivityThreshold)
        }
        
        // Ensure valid data retention period
        if dataRetentionDays < 1 || dataRetentionDays > 365 {
            dataRetentionDays = SettingsDefaults.dataRetentionDays
        }
    }
} 