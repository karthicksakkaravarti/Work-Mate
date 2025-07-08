//
//  DailyStatistics.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import Foundation
import CoreData

// MARK: - DailyStatistics Extension

@objc(DailyStatistics)
public class DailyStatistics: NSManagedObject {
    
}

extension DailyStatistics {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyStatistics> {
        return NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var totalWorkTime: Int32
    @NSManaged public var totalBreakTime: Int32
    @NSManaged public var breaksScheduled: Int32
    @NSManaged public var breaksCompleted: Int32
    @NSManaged public var breaksSkipped: Int32
    @NSManaged public var complianceRate: Float
    @NSManaged public var longestWorkStreak: Int32
    @NSManaged public var breakSessions: NSSet?

}

// MARK: - Generated accessors for breakSessions
extension DailyStatistics {

    @objc(addBreakSessionsObject:)
    @NSManaged public func addToBreakSessions(_ value: BreakSession)

    @objc(removeBreakSessionsObject:)
    @NSManaged public func removeFromBreakSessions(_ value: BreakSession)

    @objc(addBreakSessions:)
    @NSManaged public func addToBreakSessions(_ values: NSSet)

    @objc(removeBreakSessions:)
    @NSManaged public func removeFromBreakSessions(_ values: NSSet)

}

// MARK: - Convenience Methods

extension DailyStatistics {
    
    /// Computed property for formatted total work time
    var totalWorkTimeFormatted: String {
        let hours = totalWorkTime / 3600
        let minutes = (totalWorkTime % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Computed property for formatted total break time
    var totalBreakTimeFormatted: String {
        let minutes = totalBreakTime / 60
        let seconds = totalBreakTime % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Computed property for formatted longest work streak
    var longestWorkStreakFormatted: String {
        let minutes = longestWorkStreak / 60
        let seconds = longestWorkStreak % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Computed property for compliance rate as percentage
    var complianceRatePercentage: String {
        return String(format: "%.1f%%", complianceRate * 100)
    }
    
    /// Computed property for productivity score based on various metrics
    var productivityScore: Float {
        let complianceWeight: Float = 0.4
        let workTimeWeight: Float = 0.3
        let streakWeight: Float = 0.3
        
        // Normalize work time (8 hours = 100%)
        let normalizedWorkTime = min(Float(totalWorkTime) / (8 * 3600), 1.0)
        
        // Normalize longest streak (25 minutes = 100%, longer is worse)
        let idealStreak: Float = 25 * 60 // 25 minutes
        let normalizedStreak = max(0, 1.0 - abs(Float(longestWorkStreak) - idealStreak) / idealStreak)
        
        let score = (complianceRate * complianceWeight) +
                   (normalizedWorkTime * workTimeWeight) +
                   (normalizedStreak * streakWeight)
        
        return min(max(score, 0), 1.0) // Clamp between 0 and 1
    }
    
    /// Computed property for productivity grade
    var productivityGrade: String {
        let score = productivityScore
        
        switch score {
        case 0.9...1.0:
            return "A+"
        case 0.8..<0.9:
            return "A"
        case 0.7..<0.8:
            return "B+"
        case 0.6..<0.7:
            return "B"
        case 0.5..<0.6:
            return "C+"
        case 0.4..<0.5:
            return "C"
        default:
            return "D"
        }
    }
    
    /// Array of break sessions sorted by start time
    var sortedBreakSessions: [BreakSession] {
        guard let sessions = breakSessions?.allObjects as? [BreakSession] else {
            return []
        }
        
        return sessions.sorted { session1, session2 in
            guard let start1 = session1.startTime,
                  let start2 = session2.startTime else {
                return false
            }
            return start1 < start2
        }
    }
    
    /// Calculate and update statistics based on break sessions
    func recalculateStatistics() {
        let sessions = sortedBreakSessions
        
        // Reset counters
        breaksScheduled = Int32(sessions.count)
        breaksCompleted = 0
        breaksSkipped = 0
        totalBreakTime = 0
        
        // Calculate basic stats
        for session in sessions {
            if session.wasCompleted {
                breaksCompleted += 1
                totalBreakTime += session.actualDuration
            } else if session.wasSkipped {
                breaksSkipped += 1
            }
        }
        
        // Calculate compliance rate
        if breaksScheduled > 0 {
            complianceRate = Float(breaksCompleted) / Float(breaksScheduled)
        } else {
            complianceRate = 0.0
        }
        
        // Calculate longest work streak
        calculateLongestWorkStreak()
    }
    
    /// Calculate the longest work streak between breaks
    private func calculateLongestWorkStreak() {
        let sessions = sortedBreakSessions
        var maxStreak: Int32 = 0
        var currentStreak: Int32 = 0
        var lastBreakTime: Date?
        
        for session in sessions {
            guard let startTime = session.startTime else { continue }
            
            if let lastBreak = lastBreakTime {
                let workTime = Int32(startTime.timeIntervalSince(lastBreak))
                currentStreak += workTime
            }
            
            if session.wasCompleted {
                // Break was taken, reset streak
                maxStreak = max(maxStreak, currentStreak)
                currentStreak = 0
                lastBreakTime = session.endTime ?? startTime
            } else {
                // Break was skipped, continue accumulating streak
                lastBreakTime = startTime
            }
        }
        
        // Check final streak
        maxStreak = max(maxStreak, currentStreak)
        longestWorkStreak = maxStreak
    }
    
    /// Create a new daily statistics entry
    static func create(
        context: NSManagedObjectContext,
        date: Date
    ) -> DailyStatistics {
        let stats = DailyStatistics(context: context)
        stats.id = UUID()
        stats.date = Calendar.current.startOfDay(for: date)
        stats.totalWorkTime = 0
        stats.totalBreakTime = 0
        stats.breaksScheduled = 0
        stats.breaksCompleted = 0
        stats.breaksSkipped = 0
        stats.complianceRate = 0.0
        stats.longestWorkStreak = 0
        
        return stats
    }
    
    /// Find or create statistics for a given date
    static func findOrCreate(
        context: NSManagedObjectContext,
        date: Date
    ) -> DailyStatistics {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        let request: NSFetchRequest<DailyStatistics> = DailyStatistics.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("Error fetching daily statistics: \(error)")
        }
        
        return create(context: context, date: date)
    }
} 