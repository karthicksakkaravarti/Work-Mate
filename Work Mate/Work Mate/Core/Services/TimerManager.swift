import Foundation
import Combine

/// Manages multiple timers with pause/resume functionality for break scheduling
@MainActor
class TimerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    // MARK: - Private Properties
    private var timers: [String: TimerInfo] = [:]
    private var pauseTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    
    // MARK: - Timer Information
    private struct TimerInfo {
        let id: String
        let originalInterval: TimeInterval
        let callback: () -> Void
        let repeats: Bool
        var timer: Timer?
        var startTime: Date
        var lastFireTime: Date
        var remainingTime: TimeInterval
        var isPaused: Bool = false
        
        init(id: String, interval: TimeInterval, callback: @escaping () -> Void, repeats: Bool) {
            self.id = id
            self.originalInterval = interval
            self.callback = callback
            self.repeats = repeats
            self.startTime = Date()
            self.lastFireTime = Date()
            self.remainingTime = interval
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts a new timer with the specified configuration
    /// - Parameters:
    ///   - id: Unique identifier for the timer
    ///   - interval: Time interval in seconds
    ///   - repeats: Whether the timer should repeat
    ///   - callback: Closure to execute when timer fires
    func startTimer(id: String, interval: TimeInterval, repeats: Bool = false, callback: @escaping () -> Void) {
        // Stop existing timer with same ID if it exists
        stopTimer(id: id)
        
        var timerInfo = TimerInfo(id: id, interval: interval, callback: callback, repeats: repeats)
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Update last fire time
                if var info = self.timers[id] {
                    info.lastFireTime = Date()
                    self.timers[id] = info
                }
                
                // Execute callback
                callback()
                
                // Remove timer if it doesn't repeat
                if !repeats {
                    self.stopTimer(id: id)
                }
            }
        }
        
        timerInfo.timer = timer
        timers[id] = timerInfo
        
        updateRunningState()
    }
    
    /// Stops a specific timer
    /// - Parameter id: Timer identifier to stop
    func stopTimer(id: String) {
        if let timerInfo = timers[id] {
            timerInfo.timer?.invalidate()
            timers.removeValue(forKey: id)
        }
        
        updateRunningState()
    }
    
    /// Stops all active timers
    func stopAllTimers() {
        for (_, timerInfo) in timers {
            timerInfo.timer?.invalidate()
        }
        timers.removeAll()
        
        updateRunningState()
    }
    
    /// Pauses all active timers
    func pauseAllTimers() {
        guard !isPaused else { return }
        
        pauseTime = Date()
        
        // Calculate remaining time for each timer and pause them
        for (id, var timerInfo) in timers {
            let elapsed = Date().timeIntervalSince(timerInfo.lastFireTime)
            timerInfo.remainingTime = max(0, timerInfo.originalInterval - elapsed)
            timerInfo.isPaused = true
            
            // Invalidate the current timer
            timerInfo.timer?.invalidate()
            timerInfo.timer = nil
            
            timers[id] = timerInfo
        }
        
        isPaused = true
    }
    
    /// Resumes all paused timers
    func resumeAllTimers() {
        guard isPaused else { return }
        
        // Calculate total pause duration
        if let pauseStart = pauseTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        // Resume each timer with remaining time
        for (id, var timerInfo) in timers {
            guard timerInfo.isPaused else { continue }
            
            let timer = Timer.scheduledTimer(withTimeInterval: timerInfo.remainingTime, repeats: timerInfo.repeats) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // Update last fire time
                    if var info = self.timers[id] {
                        info.lastFireTime = Date()
                        self.timers[id] = info
                    }
                    
                    // Execute callback
                    timerInfo.callback()
                    
                    // If it repeats, schedule the next occurrence
                    if timerInfo.repeats {
                        self.scheduleRepeatingTimer(id: id, timerInfo: timerInfo)
                    } else {
                        self.stopTimer(id: id)
                    }
                }
            }
            
            timerInfo.timer = timer
            timerInfo.isPaused = false
            timerInfo.lastFireTime = Date()
            timers[id] = timerInfo
        }
        
        isPaused = false
        pauseTime = nil
        updateRunningState()
    }
    
    /// Gets the remaining time for a specific timer
    /// - Parameter id: Timer identifier
    /// - Returns: Remaining time in seconds, or nil if timer doesn't exist
    func getRemainingTime(for id: String) -> TimeInterval? {
        guard let timerInfo = timers[id] else { return nil }
        
        if timerInfo.isPaused {
            return timerInfo.remainingTime
        } else {
            let elapsed = Date().timeIntervalSince(timerInfo.lastFireTime)
            return max(0, timerInfo.originalInterval - elapsed)
        }
    }
    
    /// Checks if a specific timer exists and is active
    /// - Parameter id: Timer identifier
    /// - Returns: True if timer exists and is active
    func isTimerActive(id: String) -> Bool {
        return timers[id] != nil
    }
    
    /// Gets all active timer IDs
    var activeTimerIds: [String] {
        return Array(timers.keys)
    }
    
    /// Gets the total number of active timers
    var activeTimerCount: Int {
        return timers.count
    }
    
    // MARK: - Private Methods
    
    private func scheduleRepeatingTimer(id: String, timerInfo: TimerInfo) {
        let timer = Timer.scheduledTimer(withTimeInterval: timerInfo.originalInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Update last fire time
                if var info = self.timers[id] {
                    info.lastFireTime = Date()
                    self.timers[id] = info
                }
                
                // Execute callback
                timerInfo.callback()
            }
        }
        
        var updatedInfo = timerInfo
        updatedInfo.timer = timer
        updatedInfo.lastFireTime = Date()
        timers[id] = updatedInfo
    }
    
    private func updateRunningState() {
        let wasRunning = isRunning
        isRunning = !timers.isEmpty
        
        // Reset pause state if no timers are running
        if !isRunning {
            isPaused = false
            pauseTime = nil
            totalPausedDuration = 0
        }
    }
}

// MARK: - Timer Constants
extension TimerManager {
    enum TimerID {
        static let microBreak = "micro_break"
        static let regularBreak = "regular_break"
        static let activityCheck = "activity_check"
        static let breakDuration = "break_duration"
        static let smartSchedulingCheck = "smart_scheduling_check"
    }
} 