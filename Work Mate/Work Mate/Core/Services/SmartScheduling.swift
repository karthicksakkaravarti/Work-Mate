//
//  SmartScheduling.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import EventKit
import AppKit

/// Reasons why a break might be delayed
enum DelayReason: String, CaseIterable, Codable {
    case calendarEvent = "calendar_event"
    case meeting = "meeting"
    case presentation = "presentation"
    case blacklistedApp = "blacklisted_app"
    case fullscreenApp = "fullscreen_app"
    case systemPresentation = "system_presentation"
    case focusMode = "focus_mode"
    case doNotDisturb = "do_not_disturb"
    case userBusy = "user_busy"
    case criticalTask = "critical_task"
    
    var displayName: String {
        switch self {
        case .calendarEvent:
            return "Calendar Event"
        case .meeting:
            return "Meeting in Progress"
        case .presentation:
            return "Presentation Mode"
        case .blacklistedApp:
            return "Excluded Application"
        case .fullscreenApp:
            return "Fullscreen Application"
        case .systemPresentation:
            return "System Presentation"
        case .focusMode:
            return "Focus Mode Active"
        case .doNotDisturb:
            return "Do Not Disturb"
        case .userBusy:
            return "User Busy"
        case .criticalTask:
            return "Critical Task"
        }
    }
    
    var description: String {
        switch self {
        case .calendarEvent:
            return "A calendar event is currently active"
        case .meeting:
            return "A meeting is in progress"
        case .presentation:
            return "Presentation mode is detected"
        case .blacklistedApp:
            return "The current app is excluded from breaks"
        case .fullscreenApp:
            return "A fullscreen app is running"
        case .systemPresentation:
            return "System is in presentation mode"
        case .focusMode:
            return "Focus mode is currently active"
        case .doNotDisturb:
            return "Do Not Disturb is enabled"
        case .userBusy:
            return "User appears to be busy"
        case .criticalTask:
            return "Critical task is being performed"
        }
    }
}

/// Smart scheduling decision result
struct SchedulingDecision {
    let shouldDelay: Bool
    let reason: DelayReason?
    let suggestedDelay: TimeInterval?
    let nextAvailableTime: Date?
    let confidence: Double // 0.0 to 1.0
    
    static let allowBreak = SchedulingDecision(
        shouldDelay: false,
        reason: nil,
        suggestedDelay: nil,
        nextAvailableTime: nil,
        confidence: 1.0
    )
    
    static func delay(reason: DelayReason, delay: TimeInterval? = nil, nextTime: Date? = nil, confidence: Double = 0.8) -> SchedulingDecision {
        return SchedulingDecision(
            shouldDelay: true,
            reason: reason,
            suggestedDelay: delay,
            nextAvailableTime: nextTime,
            confidence: confidence
        )
    }
}

/// Smart scheduling service that determines when breaks should be delayed
@MainActor
class SmartScheduling: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isEnabled: Bool = true
    @Published var currentDelayReason: DelayReason?
    @Published var nextAvailableTime: Date?
    @Published var blacklistedApps: Set<String> = []
    @Published var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let eventStore = EKEventStore()
    private let workspace = NSWorkspace.shared
    private let settingsManager: SettingsManager
    private let calendarIntegration: CalendarIntegration
    private let appMonitor: AppMonitor
    
    // MARK: - Configuration
    private let maxDelayDuration: TimeInterval = 30 * 60 // 30 minutes max delay
    private let minDelayDuration: TimeInterval = 5 * 60  // 5 minutes min delay
    
    // MARK: - Initialization
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        self.calendarIntegration = CalendarIntegration(eventStore: eventStore)
        self.appMonitor = AppMonitor(workspace: workspace)
        
        setupInitialConfiguration()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Determines if a break should be delayed based on current context
    func evaluateBreakTiming() -> SchedulingDecision {
        guard isEnabled else {
            return .allowBreak
        }
        
        // Check multiple factors in order of priority
        
        // 1. Check for active calendar events
        if let calendarDecision = checkCalendarConflicts() {
            return calendarDecision
        }
        
        // 2. Check for blacklisted applications
        if let appDecision = checkBlacklistedApps() {
            return appDecision
        }
        
        // 3. Check for fullscreen applications
        if let fullscreenDecision = checkFullscreenApps() {
            return fullscreenDecision
        }
        
        // 4. Check for presentation mode
        if let presentationDecision = checkPresentationMode() {
            return presentationDecision
        }
        
        // 5. Check for system Do Not Disturb
        if let dndDecision = checkDoNotDisturb() {
            return dndDecision
        }
        
        // All checks passed - allow the break
        currentDelayReason = nil
        nextAvailableTime = nil
        return .allowBreak
    }
    
    /// Get the next available time for a break
    func estimateNextAvailableTime() -> Date? {
        let decision = evaluateBreakTiming()
        
        if !decision.shouldDelay {
            return Date()
        }
        
        // Calculate based on different delay reasons
        switch decision.reason {
        case .calendarEvent, .meeting:
            return calendarIntegration.getNextAvailableSlot()
        case .blacklistedApp, .fullscreenApp:
            // Check every 5 minutes for app changes
            return Date().addingTimeInterval(5 * 60)
        case .presentation, .systemPresentation:
            // Check every 10 minutes for presentation mode changes
            return Date().addingTimeInterval(10 * 60)
        case .doNotDisturb, .focusMode:
            // Check every 15 minutes for DND changes
            return Date().addingTimeInterval(15 * 60)
        default:
            // Default fallback
            return Date().addingTimeInterval(minDelayDuration)
        }
    }
    
    /// Add an app to the blacklist
    func addBlacklistedApp(_ bundleIdentifier: String) {
        blacklistedApps.insert(bundleIdentifier)
        saveBlacklistedApps()
    }
    
    /// Remove an app from the blacklist
    func removeBlacklistedApp(_ bundleIdentifier: String) {
        blacklistedApps.remove(bundleIdentifier)
        saveBlacklistedApps()
    }
    
    /// Request calendar permissions
    func requestCalendarPermission() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.calendarPermissionStatus = granted ? .fullAccess : .denied
            }
        } catch {
            print("Error requesting calendar permission: \(error)")
            await MainActor.run {
                self.calendarPermissionStatus = .denied
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialConfiguration() {
        // Load saved blacklisted apps
        loadBlacklistedApps()
        
        // Check calendar permission status
        calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
        
        // Load settings
        isEnabled = settingsManager.enableSmartScheduling
    }
    
    private func startMonitoring() {
        // Start monitoring apps and system state
        appMonitor.startMonitoring()
        calendarIntegration.startMonitoring()
    }
    
    private func checkCalendarConflicts() -> SchedulingDecision? {
        guard calendarPermissionStatus == .fullAccess else {
            return nil
        }
        
        let conflicts = calendarIntegration.getCurrentConflicts()
        
        if let activeEvent = conflicts.first,
           let endTime = activeEvent.endDate {
            let delay = endTime.timeIntervalSince(Date())
            
            return .delay(
                reason: .calendarEvent,
                delay: max(delay, minDelayDuration),
                nextTime: endTime,
                confidence: 0.9
            )
        }
        
        return nil
    }
    
    private func checkBlacklistedApps() -> SchedulingDecision? {
        guard let frontmostApp = appMonitor.frontmostApplication else {
            return nil
        }
        
        if blacklistedApps.contains(frontmostApp.bundleIdentifier ?? "") {
            return .delay(
                reason: .blacklistedApp,
                delay: minDelayDuration,
                confidence: 1.0
            )
        }
        
        return nil
    }
    
    private func checkFullscreenApps() -> SchedulingDecision? {
        if appMonitor.isFullscreenAppActive() {
            return .delay(
                reason: .fullscreenApp,
                delay: minDelayDuration,
                confidence: 0.8
            )
        }
        
        return nil
    }
    
    private func checkPresentationMode() -> SchedulingDecision? {
        if appMonitor.isPresentationModeActive() {
            return .delay(
                reason: .presentation,
                delay: 10 * 60, // 10 minutes for presentations
                confidence: 0.9
            )
        }
        
        return nil
    }
    
    private func checkDoNotDisturb() -> SchedulingDecision? {
        if appMonitor.isDoNotDisturbActive {
            return .delay(
                reason: .doNotDisturb,
                delay: 15 * 60, // 15 minutes
                confidence: 0.7
            )
        }
        
        return nil
    }
    
    private func loadBlacklistedApps() {
        let saved = UserDefaults.standard.stringArray(forKey: SettingsKeys.blacklistedApps) ?? []
        blacklistedApps = Set(saved)
    }
    
    private func saveBlacklistedApps() {
        UserDefaults.standard.set(Array(blacklistedApps), forKey: SettingsKeys.blacklistedApps)
    }
}

// MARK: - Extensions

extension SmartScheduling {
    
    /// Get a human-readable description of the current scheduling state
    var statusDescription: String {
        if !isEnabled {
            return "Smart scheduling is disabled"
        }
        
        let decision = evaluateBreakTiming()
        
        if decision.shouldDelay {
            let reason = decision.reason?.displayName ?? "Unknown reason"
            return "Breaks delayed: \(reason)"
        } else {
            return "Ready for breaks"
        }
    }
    
    /// Get the confidence level as a percentage string
    var confidenceDescription: String {
        let decision = evaluateBreakTiming()
        let percentage = Int(decision.confidence * 100)
        return "\(percentage)%"
    }
} 