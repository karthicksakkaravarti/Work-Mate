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

enum BreakType: String, CaseIterable {
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
    
    var defaultDuration: Int32 {
        switch self {
        case .micro:
            return 30 // 30 seconds
        case .regular:
            return 300 // 5 minutes
        case .custom:
            return 60 // 1 minute (can be customized)
        }
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

enum SkipReason: String, CaseIterable {
    case userRequest = "user_request"
    case meeting = "meeting"
    case presentation = "presentation"
    case blacklistedApp = "blacklisted_app"
    case systemUnavailable = "system_unavailable"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .userRequest:
            return "User Requested"
        case .meeting:
            return "Meeting in Progress"
        case .presentation:
            return "Presentation Mode"
        case .blacklistedApp:
            return "Blacklisted App Active"
        case .systemUnavailable:
            return "System Unavailable"
        case .other:
            return "Other Reason"
        }
    }
} 