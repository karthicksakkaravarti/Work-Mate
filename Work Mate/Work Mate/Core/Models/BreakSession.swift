//
//  BreakSession.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import Foundation
import CoreData

// MARK: - BreakSession Extension

@objc(BreakSession)
public class BreakSession: NSManagedObject {
    
}

extension BreakSession {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BreakSession> {
        return NSFetchRequest<BreakSession>(entityName: "BreakSession")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var scheduledDuration: Int32
    @NSManaged public var actualDuration: Int32
    @NSManaged public var breakType: String?
    @NSManaged public var wasCompleted: Bool
    @NSManaged public var wasSkipped: Bool
    @NSManaged public var skipReason: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var dailyStatistics: DailyStatistics?

}

// MARK: - Convenience Methods

extension BreakSession {
    
    /// Computed property for break duration in a more readable format
    var durationString: String {
        let duration = actualDuration > 0 ? actualDuration : scheduledDuration
        let minutes = duration / 60
        let seconds = duration % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Computed property for break status
    var status: BreakStatus {
        if wasSkipped {
            return .skipped
        } else if wasCompleted {
            return .completed
        } else if endTime != nil {
            return .interrupted
        } else {
            return .inProgress
        }
    }
    
    /// Computed property for break type enum
    var type: BreakType {
        switch breakType?.lowercased() {
        case "micro":
            return .micro
        case "regular":
            return .regular
        case "custom":
            return .custom
        default:
            return .micro
        }
    }
    
    /// Mark the break session as completed
    func markAsCompleted() {
        self.endTime = Date()
        self.wasCompleted = true
        self.wasSkipped = false
        
        if let start = startTime, let end = endTime {
            self.actualDuration = Int32(end.timeIntervalSince(start))
        }
    }
    
    /// Mark the break session as skipped with a reason
    func markAsSkipped(reason: SkipReason) {
        self.endTime = Date()
        self.wasSkipped = true
        self.wasCompleted = false
        self.skipReason = reason.rawValue
        self.actualDuration = 0
    }
    
    /// Create a new break session
    static func create(
        context: NSManagedObjectContext,
        type: BreakType,
        scheduledDuration: Int32,
        startTime: Date = Date()
    ) -> BreakSession {
        let session = BreakSession(context: context)
        session.id = UUID()
        session.startTime = startTime
        session.breakType = type.rawValue
        session.scheduledDuration = scheduledDuration
        session.actualDuration = 0
        session.wasCompleted = false
        session.wasSkipped = false
        session.createdAt = Date()
        
        return session
    }
}

// MARK: - Supporting Enums

enum BreakType: String, CaseIterable, Codable {
    case micro = "micro"
    case regular = "regular"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .micro:
            return "Micro Break"
        case .regular:
            return "Regular Break"
        case .custom:
            return "Custom Break"
        }
    }
    
    var defaultInterval: TimeInterval {
        switch self {
        case .micro:
            return 1 * 60 // 1 minute for testing
        case .regular:
            return 2 * 60 // 2 minutes for testing
        case .custom:
            return 3 * 60 // 3 minutes for testing
        }
    }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .micro:
            return 30 // 30 seconds
        case .regular:
            return 5 * 60 // 5 minutes
        case .custom:
            return 2 * 60 // 2 minutes default
        }
    }
    
    // Keep the Int32 version for Core Data compatibility
    var defaultDurationInt32: Int32 {
        return Int32(defaultDuration)
    }
}

enum BreakStatus: String, CaseIterable {
    case inProgress = "in_progress"
    case completed = "completed"
    case skipped = "skipped"
    case interrupted = "interrupted"
    
    var displayName: String {
        switch self {
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        case .interrupted:
            return "Interrupted"
        }
    }
}

enum SkipReason: String, CaseIterable, Codable {
    case userSkipped = "user_skipped"
    case calendarConflict = "calendar_conflict"
    case blacklistedApp = "blacklisted_app"
    case inactivity = "inactivity"
    case systemSleep = "system_sleep"
    case fullscreenApp = "fullscreen_app"
    case presentationMode = "presentation_mode"
    case userRequest = "user_request"
    case meeting = "meeting"
    case presentation = "presentation"
    case systemUnavailable = "system_unavailable"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .userSkipped:
            return "Manually Skipped"
        case .calendarConflict:
            return "Meeting in Progress"
        case .blacklistedApp:
            return "App Excluded"
        case .inactivity:
            return "User Inactive"
        case .systemSleep:
            return "System Sleep"
        case .fullscreenApp:
            return "Fullscreen App"
        case .presentationMode:
            return "Presentation Mode"
        case .userRequest:
            return "User Requested"
        case .meeting:
            return "Meeting in Progress"
        case .presentation:
            return "Presentation Mode"
        case .systemUnavailable:
            return "System Unavailable"
        case .other:
            return "Other Reason"
        }
    }
}

// MARK: - Additional Types for Break Scheduling

/// Status of a break session
enum BreakSessionStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case skipped = "skipped"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        case .cancelled:
            return "Cancelled"
        }
    }
}

/// Configuration for break timing
struct BreakConfiguration: Codable, Equatable {
    let type: BreakType
    let interval: TimeInterval
    let duration: TimeInterval
    let enabled: Bool
    
    init(type: BreakType, interval: TimeInterval? = nil, duration: TimeInterval? = nil, enabled: Bool = true) {
        self.type = type
        self.interval = interval ?? type.defaultInterval
        self.duration = duration ?? type.defaultDuration
        self.enabled = enabled
    }
    
    static let defaultMicro = BreakConfiguration(type: .micro)
    static let defaultRegular = BreakConfiguration(type: .regular)
    
    /// Returns the interval in minutes for display purposes
    var intervalMinutes: Int {
        return Int(interval / 60)
    }
    
    /// Returns the duration in seconds for display purposes
    var durationSeconds: Int {
        return Int(duration)
    }
    
    /// Returns the duration in minutes for display purposes
    var durationMinutes: Int {
        return Int(duration / 60)
    }
}

/// Represents the current state of break scheduling
enum SchedulerState: String, CaseIterable {
    case stopped = "stopped"
    case running = "running"
    case paused = "paused"
    case disabled = "disabled"
    
    var displayName: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .disabled:
            return "Disabled"
        }
    }
    
    var isActive: Bool {
        return self == .running
    }
}

/// Represents a scheduled break with timing information
struct ScheduledBreak: Identifiable, Equatable {
    let id = UUID()
    let type: BreakType
    let scheduledTime: Date
    let duration: TimeInterval
    var status: BreakSessionStatus
    var actualStartTime: Date?
    var actualEndTime: Date?
    var skipReason: SkipReason?
    
    init(type: BreakType, scheduledTime: Date, duration: TimeInterval) {
        self.type = type
        self.scheduledTime = scheduledTime
        self.duration = duration
        self.status = .scheduled
    }
    
    /// Time remaining until the break should start
    var timeUntilBreak: TimeInterval {
        return max(0, scheduledTime.timeIntervalSinceNow)
    }
    
    /// Whether this break is overdue
    var isOverdue: Bool {
        return scheduledTime < Date() && status == .scheduled
    }
    
    /// Actual duration of the break if completed
    var actualDuration: TimeInterval? {
        guard let start = actualStartTime, let end = actualEndTime else { return nil }
        return end.timeIntervalSince(start)
    }
}