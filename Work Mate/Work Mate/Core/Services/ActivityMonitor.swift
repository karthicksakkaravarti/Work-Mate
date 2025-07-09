//
//  ActivityMonitor.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import AppKit
import Combine
import CoreGraphics

/// User activity status
enum ActivityStatus: String, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case away = "away"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case .away:
            return "Away"
        case .unknown:
            return "Unknown"
        }
    }
    
    var description: String {
        switch self {
        case .active:
            return "User is actively using the computer"
        case .inactive:
            return "No recent keyboard or mouse activity"
        case .away:
            return "User appears to be away from computer"
        case .unknown:
            return "Activity status cannot be determined"
        }
    }
    
    var shouldPauseBreaks: Bool {
        return self != .active
    }
}

/// Activity monitoring configuration
struct ActivityMonitorConfig {
    let inactivityThreshold: TimeInterval // Seconds of inactivity before considering user inactive
    let awayThreshold: TimeInterval       // Seconds of inactivity before considering user away
    let checkInterval: TimeInterval       // How often to check activity status
    let enableKeyboardMonitoring: Bool    // Monitor keyboard events
    let enableMouseMonitoring: Bool       // Monitor mouse events
    let enableAppMonitoring: Bool         // Monitor active application changes
    
    static let `default` = ActivityMonitorConfig(
        inactivityThreshold: 120,      // 2 minutes
        awayThreshold: 600,            // 10 minutes
        checkInterval: 5,              // 5 seconds
        enableKeyboardMonitoring: true,
        enableMouseMonitoring: true,
        enableAppMonitoring: true
    )
}

/// Helper class to store observer references for nonisolated cleanup
private class ObserverCleanupStorage {
    private var observers: [NSObjectProtocol] = []
    private let queue = DispatchQueue(label: "observer.cleanup", attributes: .concurrent)
    
    func store(_ observer: NSObjectProtocol) {
        queue.async(flags: .barrier) {
            self.observers.append(observer)
        }
    }
    
    func removeAll() {
        queue.sync {
            let notificationCenter = NSWorkspace.shared.notificationCenter
            for observer in observers {
                notificationCenter.removeObserver(observer)
            }
            observers.removeAll()
        }
    }
}

/// Monitors user activity using system events and CGEventSource
@MainActor
class ActivityMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isMonitoring: Bool = false
    @Published var currentStatus: ActivityStatus = .unknown
    @Published var lastActivityTime: Date = Date()
    @Published var inactivityDuration: TimeInterval = 0
    @Published var currentApplication: NSRunningApplication?
    @Published var hasPermission: Bool = false
    
    // MARK: - Private Properties
    private var config: ActivityMonitorConfig
    private let permissionManager = PermissionManager.shared
    private let settingsManager = SettingsManager.shared
    
    private var monitoringTimer: Timer?
    private var timerForCleanup: Timer?
    private var lastEventTime: Date = Date()
    private var lastAppCheck: Date = Date()
    
    // Activity tracking
    private var keyboardEventCount: Int = 0
    private var mouseEventCount: Int = 0
    private var lastKeyboardEvent: Date = Date()
    private var lastMouseEvent: Date = Date()
    
    // NSWorkspace observations
    private var activeAppObserver: NSObjectProtocol?
    private var screenSleepObserver: NSObjectProtocol?
    private var screenWakeObserver: NSObjectProtocol?
    
    // Store observer references for nonisolated cleanup
    nonisolated private let observerCleanupStorage = ObserverCleanupStorage()
    
    // MARK: - Computed Properties
    var isUserActive: Bool {
        return currentStatus == .active
    }
    
    var timeSinceLastActivity: TimeInterval {
        return Date().timeIntervalSince(lastActivityTime)
    }
    
    var activitySummary: String {
        let duration = timeSinceLastActivity
        if duration < config.inactivityThreshold {
            return "Active"
        } else if duration < config.awayThreshold {
            return "Inactive for \(duration.formattedString)"
        } else {
            return "Away for \(duration.formattedString)"
        }
    }
    
    // MARK: - Initialization
    init(config: ActivityMonitorConfig = .default) {
        self.config = config
        setupObservers()
        updatePermissionStatus()
    }
    
    deinit {
        // Clean up synchronously without main actor calls
        performSynchronousCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring user activity
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Check permissions first
        updatePermissionStatus()
        guard hasPermission else {
            print("ActivityMonitor: Cannot start monitoring without accessibility permission")
            return
        }
        
        isMonitoring = true
        lastActivityTime = Date()
        lastEventTime = Date()
        currentStatus = .active
        
        startPeriodicCheck()
        
        print("ActivityMonitor: Started monitoring user activity")
        
        // Post notification
        NotificationCenter.default.post(
            name: .activityStatusChanged,
            object: nil,
            userInfo: ["status": currentStatus.rawValue, "monitoring": true]
        )
    }
    
    /// Stop monitoring user activity
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        currentStatus = .unknown
        
        stopPeriodicCheck()
        
        // Clean up observers
        removeObservers()
        cleanupObservers()
        
        print("ActivityMonitor: Stopped monitoring user activity")
        
        // Post notification
        NotificationCenter.default.post(
            name: .activityStatusChanged,
            object: nil,
            userInfo: ["status": currentStatus.rawValue, "monitoring": false]
        )
    }
    
    /// Request accessibility permissions if needed
    func requestPermissions() async {
        await permissionManager.requestAllPermissions()
        updatePermissionStatus()
        
        if hasPermission && !isMonitoring {
            startMonitoring()
        }
    }
    
    /// Update monitoring configuration
    func updateConfig(_ newConfig: ActivityMonitorConfig) {
        let wasMonitoring = isMonitoring
        
        if wasMonitoring {
            stopMonitoring()
        }
        
        config = newConfig
        
        if wasMonitoring {
            startMonitoring()
        }
    }
    
    /// Update configuration from settings manager
    func updateConfigFromSettings() {
        let newConfig = ActivityMonitorConfig(
            inactivityThreshold: TimeInterval(settingsManager.inactivityThreshold),
            awayThreshold: TimeInterval(settingsManager.inactivityThreshold * 5), // 5x inactivity threshold
            checkInterval: 5, // Keep fixed at 5 seconds
            enableKeyboardMonitoring: true,
            enableMouseMonitoring: true,
            enableAppMonitoring: true
        )
        updateConfig(newConfig)
    }
    
    /// Get detailed activity statistics
    func getActivityStatistics() -> [String: Any] {
        return [
            "isMonitoring": isMonitoring,
            "currentStatus": currentStatus.rawValue,
            "lastActivityTime": lastActivityTime.timeIntervalSince1970,
            "inactivityDuration": inactivityDuration,
            "timeSinceLastActivity": timeSinceLastActivity,
            "keyboardEventCount": keyboardEventCount,
            "mouseEventCount": mouseEventCount,
            "currentApplication": currentApplication?.bundleIdentifier ?? "unknown",
            "hasPermission": hasPermission
        ]
    }
    
    /// Reset activity tracking (useful for testing)
    func resetActivityTracking() {
        lastActivityTime = Date()
        lastEventTime = Date()
        inactivityDuration = 0
        keyboardEventCount = 0
        mouseEventCount = 0
        updateActivityStatus()
    }
    
    /// Force an activity update check
    func checkActivityNow() {
        updateActivityFromSystemEvents()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        // Monitor active application changes
        let activeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationChange(notification)
        }
        activeAppObserver = activeObserver
        observerCleanupStorage.store(activeObserver)
        
        // Monitor screen sleep/wake
        let sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenSleep()
        }
        screenSleepObserver = sleepObserver
        observerCleanupStorage.store(sleepObserver)
        
        let wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        }
        screenWakeObserver = wakeObserver
        observerCleanupStorage.store(wakeObserver)
    }
    
    private func removeObservers() {
        // Use the cleanup storage for consistent observer removal
        observerCleanupStorage.removeAll()
    }
    
    private func cleanupObservers() {
        activeAppObserver = nil
        screenSleepObserver = nil
        screenWakeObserver = nil
    }
    
    nonisolated private func performSynchronousCleanup() {
        // Clean up all observers through the nonisolated cleanup storage
        observerCleanupStorage.removeAll()
    }
    
    private func updatePermissionStatus() {
        hasPermission = permissionManager.isGranted(.accessibility)
    }
    
    private func startPeriodicCheck() {
        stopPeriodicCheck() // Ensure no duplicate timers
        
        let timer = Timer.scheduledTimer(withTimeInterval: config.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivityFromSystemEvents()
            }
        }
        monitoringTimer = timer
        timerForCleanup = timer
    }
    
    private func stopPeriodicCheck() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        timerForCleanup?.invalidate()
        timerForCleanup = nil
    }
    
    private func updateActivityFromSystemEvents() {
        guard isMonitoring && hasPermission else { return }
        
        // Get time since last input event
        let secondsSinceLastEvent = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        
        let secondsSinceLastKeyEvent = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        
        // Use the most recent of mouse or keyboard activity
        let timeSinceLastInput = min(secondsSinceLastEvent, secondsSinceLastKeyEvent)
        
        // Update activity time if there's been recent input
        if timeSinceLastInput < config.checkInterval {
            recordActivity()
        }
        
        // Update current application
        updateCurrentApplication()
        
        // Update status based on time since last activity
        updateActivityStatus()
    }
    
    private func recordActivity() {
        let now = Date()
        
        // Only update if it's been at least 1 second since last recorded activity
        // This prevents too frequent updates
        if now.timeIntervalSince(lastActivityTime) >= 1.0 {
            lastActivityTime = now
            lastEventTime = now
            
            // Increment event counters (approximate)
            keyboardEventCount += 1
            mouseEventCount += 1
        }
    }
    
    private func updateCurrentApplication() {
        let now = Date()
        
        // Only check application every few seconds to reduce overhead
        if now.timeIntervalSince(lastAppCheck) >= 2.0 {
            currentApplication = NSWorkspace.shared.frontmostApplication
            lastAppCheck = now
        }
    }
    
    private func updateActivityStatus() {
        let now = Date()
        let timeSinceActivity = now.timeIntervalSince(lastActivityTime)
        inactivityDuration = timeSinceActivity
        
        let previousStatus = currentStatus
        
        if timeSinceActivity < config.inactivityThreshold {
            currentStatus = .active
        } else if timeSinceActivity < config.awayThreshold {
            currentStatus = .inactive
        } else {
            currentStatus = .away
        }
        
        // Post notification if status changed
        if currentStatus != previousStatus {
            NotificationCenter.default.post(
                name: .activityStatusChanged,
                object: nil,
                userInfo: [
                    "status": currentStatus.rawValue,
                    "previousStatus": previousStatus.rawValue,
                    "inactivityDuration": timeSinceActivity
                ]
            )
            
            print("ActivityMonitor: Status changed from \(previousStatus.displayName) to \(currentStatus.displayName)")
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleApplicationChange(_ notification: Notification) {
        guard config.enableAppMonitoring else { return }
        
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            currentApplication = app
            
            // Consider app switching as user activity
            recordActivity()
        }
    }
    
    private func handleScreenSleep() {
        print("ActivityMonitor: Screen went to sleep")
        
        // When screen sleeps, user is definitely inactive
        currentStatus = .away
        
        // Post notification
        NotificationCenter.default.post(
            name: .activityStatusChanged,
            object: nil,
            userInfo: ["status": currentStatus.rawValue, "reason": "screen_sleep"]
        )
    }
    
    private func handleScreenWake() {
        print("ActivityMonitor: Screen woke up")
        
        // When screen wakes, assume user is back
        recordActivity()
        currentStatus = .active
        
        // Post notification
        NotificationCenter.default.post(
            name: .activityStatusChanged,
            object: nil,
            userInfo: ["status": currentStatus.rawValue, "reason": "screen_wake"]
        )
    }
}

// MARK: - ActivityMonitor Extensions

extension ActivityMonitor {
    
    /// Get a user-friendly description of current activity
    var statusDescription: String {
        guard isMonitoring else {
            return "Monitoring disabled"
        }
        
        guard hasPermission else {
            return "Permission required"
        }
        
        let duration = timeSinceLastActivity
        switch currentStatus {
        case .active:
            return "Active now"
        case .inactive:
            return "Inactive for \(duration.formattedString)"
        case .away:
            return "Away for \(duration.formattedString)"
        case .unknown:
            return "Status unknown"
        }
    }
    
    /// Check if the user has been inactive long enough to pause breaks
    var shouldPauseBreaks: Bool {
        return !isUserActive && settingsManager.pauseOnInactivity
    }
    
    /// Get activity level as a percentage (0-100)
    var activityLevel: Double {
        let maxInactivity = config.awayThreshold
        let currentInactivity = min(timeSinceLastActivity, maxInactivity)
        return max(0, 100 - (currentInactivity / maxInactivity * 100))
    }
    
    /// Check if a specific application bundle ID is currently active
    func isApplicationActive(_ bundleIdentifier: String) -> Bool {
        return currentApplication?.bundleIdentifier == bundleIdentifier
    }
    
    /// Get time since user was last active, formatted as string
    var formattedTimeSinceActivity: String {
        return timeSinceLastActivity.formattedString
    }
}

// MARK: - Debug and Testing Extensions

#if DEBUG
extension ActivityMonitor {
    
    /// Simulate user activity (for testing)
    func simulateActivity() {
        recordActivity()
        updateActivityStatus()
    }
    
    /// Simulate inactivity (for testing)
    func simulateInactivity(duration: TimeInterval) {
        lastActivityTime = Date().addingTimeInterval(-duration)
        updateActivityStatus()
    }
    
    /// Get debug information
    var debugInfo: [String: Any] {
        return [
            "config": [
                "inactivityThreshold": config.inactivityThreshold,
                "awayThreshold": config.awayThreshold,
                "checkInterval": config.checkInterval
            ],
            "state": [
                "isMonitoring": isMonitoring,
                "hasPermission": hasPermission,
                "currentStatus": currentStatus.rawValue,
                "lastActivityTime": lastActivityTime,
                "inactivityDuration": inactivityDuration
            ],
            "events": [
                "keyboardEventCount": keyboardEventCount,
                "mouseEventCount": mouseEventCount,
                "lastKeyboardEvent": lastKeyboardEvent,
                "lastMouseEvent": lastMouseEvent
            ]
        ]
    }
}
#endif 