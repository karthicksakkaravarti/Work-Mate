//
//  AnalyticsService.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import CoreData

/// A service to manage analytics, including recording break sessions and calculating statistics.
@MainActor
class AnalyticsService: ObservableObject {
    private let persistenceController: PersistenceController
    
    /// Initializes the service with a persistence controller.
    /// - Parameter persistenceController: The Core Data stack manager.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    /// Records a completed or skipped break session in Core Data.
    /// - Parameter session: The `BreakSession` object to record.
    func recordBreakSession(_ session: BreakSession) {
        let context = persistenceController.container.viewContext
        // The session is already in the context, so we just need to save.
        persistenceController.save()
    }
    
    /// Fetches daily statistics for a given date.
    /// - Parameter date: The date for which to retrieve statistics.
    /// - Returns: A `DailyStats` object or `nil` if no data exists.
    func getDailyStatistics(for date: Date) -> DailyStats? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<DailyStatisticsEntity> = DailyStatisticsEntity.fetchRequest()
        
        // Use a predicate to find the stats for the specific day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let entity = results.first else { return nil }
            return DailyStats(from: entity)
        } catch {
            print("Failed to fetch daily statistics: \(error)")
            return nil
        }
    }
    
    /// Generates an analytics summary for a given date range.
    /// - Parameter dateRange: The range of dates to summarize.
    /// - Returns: An `AnalyticsSummary` object.
    func getAnalyticsSummary(for dateRange: ClosedRange<Date>) -> AnalyticsSummary {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<DailyStatisticsEntity> = DailyStatisticsEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let entities = try context.fetch(fetchRequest)
            let dailyStats = entities.map { DailyStats(from: $0) }
            return AnalyticsSummary(id: UUID(), startDate: dateRange.lowerBound, endDate: dateRange.upperBound, dailyStats: dailyStats)
        } catch {
            print("Failed to fetch analytics summary: \(error)")
            return AnalyticsSummary(id: UUID(), startDate: dateRange.lowerBound, endDate: dateRange.upperBound, dailyStats: [])
        }
    }
    
    /// Calculates the user's current and longest break streak.
    /// - Parameter complianceThreshold: The minimum compliance rate to count as a successful day.
    /// - Returns: A `BreakStreak` object.
    func getBreakStreak(complianceThreshold: Double = 0.75) -> BreakStreak {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<DailyStatisticsEntity> = DailyStatisticsEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let allStats = try context.fetch(fetchRequest).map { DailyStats(from: $0) }
            return calculateStreak(from: allStats, threshold: complianceThreshold)
        } catch {
            print("Failed to fetch statistics for streak calculation: \(error)")
            return BreakStreak(currentStreak: 0, longestStreak: 0, streakStartDate: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateStreak(from stats: [DailyStats], threshold: Double) -> BreakStreak {
        var currentStreak = 0
        var longestStreak = 0
        var streakStartDate: Date?
        
        // Ensure stats are sorted by date descending
        let sortedStats = stats.sorted { $0.date > $1.date }
        
        var previousDate = Date()
        var isFirstDay = true
        
        for stat in sortedStats {
            if stat.complianceRate >= threshold {
                if isFirstDay {
                    currentStreak += 1
                    streakStartDate = stat.date
                } else {
                    // Check if the day is consecutive
                    if Calendar.current.isDate(previousDate, inSameDayAs: stat.date.addingTimeInterval(86400)) {
                        currentStreak += 1
                        streakStartDate = stat.date
                    } else {
                        // Streak broken
                        break
                    }
                }
                longestStreak = max(longestStreak, currentStreak)
                previousDate = stat.date
                isFirstDay = false
            } else {
                // Streak broken if compliance is too low
                if !isFirstDay { break }
            }
        }
        
        return BreakStreak(currentStreak: currentStreak, longestStreak: longestStreak, streakStartDate: streakStartDate)
    }
}

// MARK: - Data Mapping Extension
extension DailyStats {
    /// Initializes a `DailyStats` DTO from a Core Data entity.
    init(from entity: DailyStatisticsEntity) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.totalWorkTime = entity.totalWorkTime
        self.totalBreakTime = entity.totalBreakTime
        self.breaksScheduled = Int(entity.breaksScheduled)
        self.breaksCompleted = Int(entity.breaksCompleted)
        self.breaksSkipped = Int(entity.breaksSkipped)
    }
} 