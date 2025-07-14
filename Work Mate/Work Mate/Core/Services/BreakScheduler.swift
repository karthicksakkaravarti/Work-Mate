import Foundation
import Combine
import SwiftUI

/// Main break scheduling service that coordinates break timing and execution
@MainActor
class BreakScheduler: ObservableObject {
    
    // MARK: - Published Properties
    @Published var schedulerState: SchedulerState = .stopped
    @Published var currentBreak: ScheduledBreak?
    @Published var nextMicroBreak: Date?
    @Published var nextRegularBreak: Date?
    @Published var isBreakActive: Bool = false
    @Published var timeUntilNextBreak: TimeInterval = 0
    @Published var lastActivityTime: Date = Date()
    
    // MARK: - Dependencies
    private let timerManager: TimerManager
    private let activityMonitor: ActivityMonitor
    private let settingsManager: SettingsManager
    private let persistenceController: PersistenceController
    private let smartScheduling: SmartScheduling
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var microBreakConfiguration: BreakConfiguration = .defaultMicro
    private var regularBreakConfiguration: BreakConfiguration = .defaultRegular
    private var lastBreakTime: [BreakType: Date] = [:]
    private var pendingBreaks: [ScheduledBreak] = []
    private var activityCheckTimer: Timer?
    
    // Break scheduling constants
    private let activityCheckInterval: TimeInterval = 30 // Check activity every 30 seconds
    private let inactivityThreshold: TimeInterval = 120 // 2 minutes of inactivity
    
    // MARK: - Initialization
    
    init(timerManager: TimerManager? = nil,
         activityMonitor: ActivityMonitor,
         settingsManager: SettingsManager = SettingsManager.shared,
         persistenceController: PersistenceController = PersistenceController.shared,
         smartScheduling: SmartScheduling? = nil) {
        
        self.timerManager = timerManager ?? TimerManager()
        self.activityMonitor = activityMonitor
        self.settingsManager = settingsManager
        self.persistenceController = persistenceController
        self.smartScheduling = smartScheduling ?? SmartScheduling(settingsManager: settingsManager)
        
        setupObservers()
        loadConfigurations()
    }
    
    // MARK: - Public Methods
    
    /// Starts the break scheduling system
    func startScheduling() {
        guard schedulerState != .running else { return }
        
        schedulerState = .running
        loadConfigurations()
        scheduleNextBreaks()
        startActivityMonitoring()
        
        print("Break scheduling started")
    }
    
    /// Stops the break scheduling system
    func stopScheduling() {
        guard schedulerState != .stopped else { return }
        
        schedulerState = .stopped
        timerManager.stopAllTimers()
        stopActivityMonitoring()
        clearPendingBreaks()
        
        nextMicroBreak = nil
        nextRegularBreak = nil
        timeUntilNextBreak = 0
        
        print("Break scheduling stopped")
    }
    
    /// Pauses the break scheduling system
    func pauseScheduling() {
        guard schedulerState == .running else { return }
        
        schedulerState = .paused
        timerManager.pauseAllTimers()
        
        print("Break scheduling paused")
    }
    
    /// Resumes the break scheduling system
    func resumeScheduling() {
        guard schedulerState == .paused else { return }
        
        schedulerState = .running
        timerManager.resumeAllTimers()
        
        print("Break scheduling resumed")
    }
    
    /// Manually triggers a break of the specified type
    /// - Parameter type: The type of break to trigger
    func triggerBreak(type: BreakType) {
        let configuration = getConfiguration(for: type)
        let scheduledBreak = ScheduledBreak(
            type: type,
            scheduledTime: Date(),
            duration: configuration.duration
        )
        
        executeBreak(scheduledBreak)
    }
    
    /// Skips the current break
    /// - Parameter reason: Reason for skipping the break
    func skipCurrentBreak(reason: SkipReason = .userSkipped) {
        guard var currentBreak = currentBreak else { return }
        
        currentBreak.status = .skipped
        currentBreak.skipReason = reason
        currentBreak.actualEndTime = Date()
        
        // Save to Core Data
        saveBreakSession(currentBreak)
        
        // Clear current break and reschedule
        endCurrentBreak()
        
        print("Break skipped: \(reason.displayName)")
    }
    
    /// Pauses the current break
    func pauseCurrentBreak() {
        guard var currentBreak = currentBreak else { return }
        guard currentBreak.status == .active else { return }
        
        currentBreak.status = .paused
        self.currentBreak = currentBreak
        
        // Stop the break duration timer
        timerManager.stopTimer(id: TimerManager.TimerID.breakDuration)
        
        print("Break paused")
    }
    
    /// Resumes the current break
    func resumeCurrentBreak() {
        guard var currentBreak = currentBreak else { return }
        guard currentBreak.status == .paused else { return }
        
        currentBreak.status = .active
        self.currentBreak = currentBreak
        
        // Calculate remaining duration
        let elapsed = currentBreak.actualStartTime?.timeIntervalSinceNow ?? 0
        let remainingDuration = max(0, currentBreak.duration + elapsed)
        
        // Restart the break duration timer
        startBreakDurationTimer(duration: remainingDuration)
        
        print("Break resumed")
    }
    
    /// Gets the time until the next break of any type
    var timeUntilAnyBreak: TimeInterval {
        let microTime = nextMicroBreak?.timeIntervalSinceNow ?? .greatestFiniteMagnitude
        let regularTime = nextRegularBreak?.timeIntervalSinceNow ?? .greatestFiniteMagnitude
        
        let nextTime = min(microTime, regularTime)
        return nextTime == .greatestFiniteMagnitude ? 0 : max(0, nextTime)
    }
    
    /// Gets the type of the next scheduled break
    var nextBreakType: BreakType? {
        let microTime = nextMicroBreak?.timeIntervalSinceNow ?? .greatestFiniteMagnitude
        let regularTime = nextRegularBreak?.timeIntervalSinceNow ?? .greatestFiniteMagnitude
        
        if microTime < regularTime && microTime != .greatestFiniteMagnitude {
            return .micro
        } else if regularTime != .greatestFiniteMagnitude {
            return .regular
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe settings changes using objectWillChange since @AppStorage doesn't provide publishers directly
        settingsManager.objectWillChange
            .sink { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // Update micro break configuration
                    let newMicroConfig = BreakConfiguration(
                        type: .micro,
                        interval: TimeInterval(self.settingsManager.microBreakInterval * 60),
                        duration: TimeInterval(self.settingsManager.microBreakDuration)
                    )
                    
                    if newMicroConfig != self.microBreakConfiguration {
                        self.microBreakConfiguration = newMicroConfig
                        self.rescheduleIfNeeded()
                    }
                    
                    // Update regular break configuration
                    let newRegularConfig = BreakConfiguration(
                        type: .regular,
                        interval: TimeInterval(self.settingsManager.regularBreakInterval * 60),
                        duration: TimeInterval(self.settingsManager.regularBreakDuration)
                    )
                    
                    if newRegularConfig != self.regularBreakConfiguration {
                        self.regularBreakConfiguration = newRegularConfig
                        self.rescheduleIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe activity status using the correct published property
        activityMonitor.$currentStatus
            .map { status in
                status == .active
            }
            .sink { [weak self] isActive in
                Task { @MainActor in
                    if isActive {
                        self?.lastActivityTime = Date()
                        self?.handleActivityResume()
                    } else {
                        self?.handleInactivity()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update time until next break periodically
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTimeDisplay()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadConfigurations() {
        microBreakConfiguration = BreakConfiguration(
            type: .micro,
            interval: TimeInterval(settingsManager.microBreakInterval * 60),
            duration: TimeInterval(settingsManager.microBreakDuration)
        )
        
        regularBreakConfiguration = BreakConfiguration(
            type: .regular,
            interval: TimeInterval(settingsManager.regularBreakInterval * 60),
            duration: TimeInterval(settingsManager.regularBreakDuration)
        )
    }
    
    private func getConfiguration(for type: BreakType) -> BreakConfiguration {
        switch type {
        case .micro:
            return microBreakConfiguration
        case .regular:
            return regularBreakConfiguration
        case .custom:
            return BreakConfiguration(type: .custom)
        }
    }
    
    private func scheduleNextBreaks() {
        guard schedulerState.isActive else { return }
        
        scheduleNextBreak(type: .micro)
        scheduleNextBreak(type: .regular)
    }
    
    private func scheduleNextBreak(type: BreakType) {
        let configuration = getConfiguration(for: type)
        guard configuration.enabled else { 
            print("Break scheduling disabled for \(type.displayName)")
            return 
        }
        
        // Calculate next break time based on last break or current time
        let lastBreak = lastBreakTime[type] ?? Date()
        let nextBreakTime = lastBreak.addingTimeInterval(configuration.interval)
        
        // If the calculated next break time is in the past, schedule it for the future
        let adjustedNextBreakTime = max(nextBreakTime, Date().addingTimeInterval(5)) // At least 5 seconds from now
        
        // Update the next break time
        switch type {
        case .micro:
            nextMicroBreak = adjustedNextBreakTime
        case .regular:
            nextRegularBreak = adjustedNextBreakTime
        case .custom:
            return // Custom breaks are manually triggered
        }
        
        // Schedule timer for this break
        let timeUntilBreak = adjustedNextBreakTime.timeIntervalSinceNow
        if timeUntilBreak > 0 {
            let timerID = type == .micro ? TimerManager.TimerID.microBreak : TimerManager.TimerID.regularBreak
            
            print("Scheduling \(type.displayName) in \(Int(timeUntilBreak))s")
            
            timerManager.startTimer(id: timerID, interval: timeUntilBreak) { [weak self] in
                Task { @MainActor in
                    self?.handleBreakTimer(type: type)
                }
            }
        } else {
            print("Warning: Cannot schedule \(type.displayName) - time until break is \(timeUntilBreak)")
        }
    }
    
    private func handleBreakTimer(type: BreakType) {
        guard schedulerState.isActive else { 
            print("Break timer fired but scheduler is not active (state: \(schedulerState.displayName))")
            return 
        }
        guard !isBreakActive else { 
            print("Break timer fired but another break is already active")
            return 
        }
        
        print("Break timer fired for \(type.displayName)")
        
        // Check if user is inactive
        if !activityMonitor.isUserActive {
            print("Skipping \(type.displayName) due to user inactivity (status: \(activityMonitor.currentStatus.displayName))")
            
            // Update last break time to now so next break is scheduled properly
            lastBreakTime[type] = Date()
            
            // Reschedule for next interval
            scheduleNextBreak(type: type)
            return
        }
        
        // Check smart scheduling decision
        let schedulingDecision = smartScheduling.evaluateBreakTiming()
        
        if schedulingDecision.shouldDelay {
            let reason = schedulingDecision.reason?.displayName ?? "Unknown reason"
            print("Delaying \(type.displayName) due to smart scheduling: \(reason)")
            
            // Determine delay duration
            let delayDuration = schedulingDecision.suggestedDelay ?? 5 * 60 // Default 5 minutes
            let nextTime = Date().addingTimeInterval(delayDuration)
            
            // Update next break time based on smart scheduling
            switch type {
            case .micro:
                nextMicroBreak = nextTime
            case .regular:
                nextRegularBreak = nextTime
            case .custom:
                break
            }
            
            // Reschedule break for the delayed time
            let timerID = type == .micro ? TimerManager.TimerID.microBreak : TimerManager.TimerID.regularBreak
            timerManager.startTimer(id: timerID, interval: delayDuration) { [weak self] in
                Task { @MainActor in
                    self?.handleBreakTimer(type: type)
                }
            }
            
            // Save the skip reason
            let skipReason: SkipReason
            switch schedulingDecision.reason {
            case .calendarEvent, .meeting:
                skipReason = .meeting
            case .blacklistedApp:
                skipReason = .blacklistedApp
            case .fullscreenApp:
                skipReason = .fullscreenApp
            case .presentation, .systemPresentation:
                skipReason = .presentation
            case .doNotDisturb, .focusMode:
                skipReason = .systemUnavailable
            default:
                skipReason = .other
            }
            
            // Record the delayed break
            recordSkippedBreak(type: type, reason: skipReason)
            return
        }
        
        print("Triggering \(type.displayName)")
        
        let configuration = getConfiguration(for: type)
        let scheduledBreak = ScheduledBreak(
            type: type,
            scheduledTime: Date(),
            duration: configuration.duration
        )
        
        executeBreak(scheduledBreak)
    }
    
    private func executeBreak(_ scheduledBreak: ScheduledBreak) {
        guard !isBreakActive else { return }
        
        var breakSession = scheduledBreak
        breakSession.status = .active
        breakSession.actualStartTime = Date()
        
        currentBreak = breakSession
        isBreakActive = true
        
        // Start break duration timer
        startBreakDurationTimer(duration: breakSession.duration)
        
        // Update last break time
        lastBreakTime[breakSession.type] = Date()
        
        print("Break started: \(breakSession.type.displayName) for \(breakSession.duration)s")
    }
    
    private func startBreakDurationTimer(duration: TimeInterval) {
        timerManager.startTimer(id: TimerManager.TimerID.breakDuration, interval: duration) { [weak self] in
            Task { @MainActor in
                self?.completeCurrentBreak()
            }
        }
    }
    
    private func completeCurrentBreak() {
        guard var currentBreak = currentBreak else { return }
        
        currentBreak.status = .completed
        currentBreak.actualEndTime = Date()
        
        // Save to Core Data
        saveBreakSession(currentBreak)
        
        // Clear current break
        endCurrentBreak()
        
        print("Break completed: \(currentBreak.type.displayName)")
    }
    
    private func endCurrentBreak() {
        currentBreak = nil
        isBreakActive = false
        
        // Schedule next breaks
        scheduleNextBreaks()
    }
    
    private func saveBreakSession(_ scheduledBreak: ScheduledBreak) {
        let context = persistenceController.container.viewContext
        
        let breakSession = BreakSession(context: context)
        breakSession.id = scheduledBreak.id
        breakSession.startTime = scheduledBreak.scheduledTime
        breakSession.endTime = scheduledBreak.actualEndTime
        breakSession.scheduledDuration = Int32(scheduledBreak.duration)
        breakSession.actualDuration = Int32(scheduledBreak.actualDuration ?? scheduledBreak.duration)
        breakSession.breakType = scheduledBreak.type.rawValue
        breakSession.wasCompleted = scheduledBreak.status == .completed
        breakSession.wasSkipped = scheduledBreak.status == .skipped
        breakSession.skipReason = scheduledBreak.skipReason?.rawValue
        breakSession.createdAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Failed to save break session: \(error)")
        }
    }
    
    private func recordSkippedBreak(type: BreakType, reason: SkipReason) {
        let configuration = getConfiguration(for: type)
        var scheduledBreak = ScheduledBreak(
            type: type,
            scheduledTime: Date(),
            duration: configuration.duration
        )
        
        scheduledBreak.status = .skipped
        scheduledBreak.skipReason = reason
        scheduledBreak.actualEndTime = Date()
        
        // Save to Core Data
        saveBreakSession(scheduledBreak)
        
        print("Recorded skipped break: \(type.displayName) - \(reason.displayName)")
    }
    
    private func startActivityMonitoring() {
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: activityCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkActivityStatus()
            }
        }
    }
    
    private func stopActivityMonitoring() {
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }
    
    private func checkActivityStatus() {
        // This method can be used for additional activity checks
        // The main activity monitoring is handled by ActivityMonitor
    }
    
    private func handleActivityResume() {
        // Resume timers if they were paused due to inactivity
        if schedulerState == .running && timerManager.isPaused {
            timerManager.resumeAllTimers()
        }
    }
    
    private func handleInactivity() {
        // Pause timers if user is inactive for too long
        if schedulerState == .running && !timerManager.isPaused {
            let inactiveDuration = Date().timeIntervalSince(lastActivityTime)
            if inactiveDuration >= inactivityThreshold {
                timerManager.pauseAllTimers()
                print("Timers paused due to inactivity")
            }
        }
    }
    
    private func rescheduleIfNeeded() {
        guard schedulerState.isActive else { return }
        
        // Stop current timers and reschedule with new settings
        timerManager.stopTimer(id: TimerManager.TimerID.microBreak)
        timerManager.stopTimer(id: TimerManager.TimerID.regularBreak)
        
        scheduleNextBreaks()
    }
    
    private func updateTimeDisplay() {
        timeUntilNextBreak = timeUntilAnyBreak
    }
    
    private func clearPendingBreaks() {
        pendingBreaks.removeAll()
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let workMateBreakScheduled = Notification.Name("workMateBreakScheduled")
    static let workMateBreakStarted = Notification.Name("workMateBreakStarted")
    static let workMateBreakCompleted = Notification.Name("workMateBreakCompleted")
    static let workMateBreakSkipped = Notification.Name("workMateBreakSkipped")
} 