//
//  PermissionManager.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import AppKit
import Combine
import ScreenCaptureKit
import EventKit

/// Permission status for various system capabilities
enum PermissionStatus: String, CaseIterable {
    case unknown = "unknown"
    case notRequested = "notRequested"
    case denied = "denied"
    case granted = "granted"
    case restricted = "restricted"
    
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notRequested:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .granted:
            return "Granted"
        case .restricted:
            return "Restricted"
        }
    }
    
    var isAuthorized: Bool {
        return self == .granted
    }
}

/// Types of permissions the app may need
enum PermissionType: String, CaseIterable {
    case accessibility = "accessibility"
    case calendar = "calendar"
    case notifications = "notifications"
    case screenRecording = "screenRecording"
    
    var displayName: String {
        switch self {
        case .accessibility:
            return "Accessibility"
        case .calendar:
            return "Calendar"
        case .notifications:
            return "Notifications"
        case .screenRecording:
            return "Screen Recording"
        }
    }
    
    var description: String {
        switch self {
        case .accessibility:
            return "Required to monitor keyboard and mouse activity for break timing"
        case .calendar:
            return "Optional: Integrates with calendar to avoid interrupting meetings"
        case .notifications:
            return "Shows break reminders and status updates"
        case .screenRecording:
            return "Optional: May be required for overlay display on some systems"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .accessibility:
            return true
        case .notifications:
            return true
        case .calendar, .screenRecording:
            return false
        }
    }
}

/// Helper class to store a timer for nonisolated cleanup
private class TimerCleanupStorage {
    private var timer: Timer?
    private let queue = DispatchQueue(label: "timer.cleanup")
    
    func store(_ timer: Timer?) {
        queue.async(flags: .barrier) {
            self.timer = timer
        }
    }
    
    func invalidate() {
        queue.sync {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}

/// Manages system permissions for Work Mate
@MainActor
class PermissionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PermissionManager()
    
    // MARK: - Published Properties
    @Published var accessibilityPermission: PermissionStatus = .unknown
    @Published var calendarPermission: PermissionStatus = .unknown
    @Published var notificationPermission: PermissionStatus = .unknown
    @Published var screenRecordingPermission: PermissionStatus = .unknown
    
    // MARK: - Private Properties
    private var permissionCheckTimer: Timer?
    private let settingsManager = SettingsManager.shared
    nonisolated private let timerCleanupStorage = TimerCleanupStorage()
    
    // MARK: - Computed Properties
    var allPermissions: [PermissionType: PermissionStatus] {
        return [
            .accessibility: accessibilityPermission,
            .calendar: calendarPermission,
            .notifications: notificationPermission,
            .screenRecording: screenRecordingPermission
        ]
    }
    
    var requiredPermissionsGranted: Bool {
        return accessibilityPermission.isAuthorized && notificationPermission.isAuthorized
    }
    
    var allRequiredPermissionsChecked: Bool {
        return accessibilityPermission != .unknown && notificationPermission != .unknown
    }
    
    // MARK: - Initialization
    private init() {
        startPeriodicPermissionCheck()
        checkAllPermissions()
    }
    
    deinit {
        performSynchronousCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Check all permissions and update status
    func checkAllPermissions() {
        checkAccessibilityPermission()
        checkCalendarPermission()
        checkNotificationPermission()
        checkScreenRecordingPermission()
    }
    
    /// Request all required permissions
    func requestAllPermissions() async {
        // Mark that permissions have been requested
        settingsManager.permissionsRequested = true
        
        // Request notifications first (doesn't require user interaction)
        await requestNotificationPermission()
        
        // Request accessibility (requires user to go to System Preferences)
        requestAccessibilityPermission()
        
        // Optional permissions
        if settingsManager.enableSmartScheduling {
            requestCalendarPermission()
        }
    }
    
    /// Request accessibility permission
    func requestAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            // Prompt user to enable accessibility
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            let promptResult = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            if !promptResult {
                // Show instructions to user
                DispatchQueue.main.async {
                    self.showAccessibilityInstructions()
                }
            }
        }
        
        checkAccessibilityPermission()
    }
    
    /// Request notification permission
    @MainActor
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            // Permission has not been requested yet, so request it
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                notificationPermission = granted ? .granted : .denied
                
                // Post notification about permission change
                NotificationCenter.default.post(name: .permissionsChanged, object: nil)
            } catch {
                print("Error requesting notification permission: \(error.localizedDescription)")
                notificationPermission = .denied
            }
        case .denied:
            // Permission was denied, guide user to settings
            print("Notification permission previously denied. Opening settings.")
            await MainActor.run {
                openNotificationPreferences()
            }
        case .authorized, .provisional, .ephemeral:
            // Permission is already granted
            print("Notification permission already granted.")
            notificationPermission = .granted
        @unknown default:
            print("Unknown notification authorization status.")
            notificationPermission = .unknown
        }
    }
    
    /// Request calendar permission
    func requestCalendarPermission() {
        let eventStore = EKEventStore()
        
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error requesting calendar permission: \(error)")
                        self.calendarPermission = .denied
                    } else {
                        self.calendarPermission = granted ? .granted : .denied
                    }
                    NotificationCenter.default.post(name: .permissionsChanged, object: nil)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error requesting calendar permission: \(error)")
                        self.calendarPermission = .denied
                    } else {
                        self.calendarPermission = granted ? .granted : .denied
                    }
                    NotificationCenter.default.post(name: .permissionsChanged, object: nil)
                }
            }
        }
    }
    
    /// Open system preferences for a specific permission
    func openSystemPreferences(for permissionType: PermissionType) {
        switch permissionType {
        case .accessibility:
            openAccessibilityPreferences()
        case .calendar:
            openPrivacyPreferences()
        case .notifications:
            openNotificationPreferences()
        case .screenRecording:
            openScreenRecordingPreferences()
        }
    }
    
    /// Reset permission request status (for testing)
    func resetPermissionRequests() {
        settingsManager.permissionsRequested = false
        checkAllPermissions()
    }
    
    // MARK: - Private Methods
    
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        accessibilityPermission = trusted ? .granted : .denied
    }
    
    private func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized:
            calendarPermission = .granted
        case .denied:
            calendarPermission = .denied
        case .notDetermined:
            calendarPermission = .notRequested
        case .restricted:
            calendarPermission = .restricted
        @unknown default:
            calendarPermission = .unknown
        }
    }
    
    private func checkNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self.notificationPermission = .granted
                case .denied:
                    self.notificationPermission = .denied
                case .notDetermined:
                    self.notificationPermission = .notRequested
                case .provisional:
                    self.notificationPermission = .restricted
                case .ephemeral:
                    self.notificationPermission = .restricted
                @unknown default:
                    self.notificationPermission = .unknown
                }
            }
        }
    }
    
    private func checkScreenRecordingPermission() {
        Task { @MainActor in
            do {
                // Use the correct ScreenCaptureKit API to get shareable content.
                // If this succeeds, we have screen recording permission.
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                self.screenRecordingPermission = .granted
            } catch {
                // An error indicates that permission is denied or not yet determined.
                self.screenRecordingPermission = .denied
            }
        }
    }
    
    private func startPeriodicPermissionCheck() {
        // Invalidate existing timer before starting a new one
        stopPeriodicPermissionCheck()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAllPermissions()
        }
        permissionCheckTimer = timer
        timerCleanupStorage.store(timer)
    }
    
    private func stopPeriodicPermissionCheck() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        timerCleanupStorage.invalidate()
    }
    
    // MARK: - System Preferences
    
    private func openAccessibilityPreferences() {
        let prefPath = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: prefPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openPrivacyPreferences() {
        let prefPath = "x-apple.systempreferences:com.apple.preference.security?Privacy"
        if let url = URL(string: prefPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openNotificationPreferences() {
        let prefPath = "x-apple.systempreferences:com.apple.preference.notifications"
        if let url = URL(string: prefPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openScreenRecordingPreferences() {
        let prefPath = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let url = URL(string: prefPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showAccessibilityInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Work Mate needs accessibility permission to monitor your activity and provide accurate break timing.
        
        To enable this permission:
        1. Click "Open System Preferences" below
        2. Find "Work Mate" in the list
        3. Check the box next to "Work Mate"
        4. Return to this app
        
        This permission is required for the app to function properly.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
    
    nonisolated private func performSynchronousCleanup() {
        timerCleanupStorage.invalidate()
    }
}

// MARK: - Permission Extensions

extension PermissionManager {
    
    /// Get permission status for a specific type
    func status(for type: PermissionType) -> PermissionStatus {
        return allPermissions[type] ?? .unknown
    }
    
    /// Check if a specific permission is granted
    func isGranted(_ type: PermissionType) -> Bool {
        return status(for: type).isAuthorized
    }
    
    /// Get a list of denied required permissions
    var deniedRequiredPermissions: [PermissionType] {
        return PermissionType.allCases.filter { type in
            type.isRequired && !isGranted(type) && status(for: type) != .unknown
        }
    }
    
    /// Get a list of not requested required permissions
    var notRequestedRequiredPermissions: [PermissionType] {
        return PermissionType.allCases.filter { type in
            type.isRequired && status(for: type) == .notRequested
        }
    }
    
    /// Check if we should show permission onboarding
    var shouldShowPermissionOnboarding: Bool {
        return !settingsManager.permissionsRequested || !requiredPermissionsGranted
    }
}

// MARK: - Imports for EventKit and UserNotifications

import EventKit
import UserNotifications 
