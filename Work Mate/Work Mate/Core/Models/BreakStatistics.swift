//
//  BreakStatistics.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation

/// Represents daily analytics for break activity.
struct DailyStats: Identifiable, Codable {
    let id: UUID
    let date: Date
    let totalWorkTime: TimeInterval
    let totalBreakTime: TimeInterval
    let breaksScheduled: Int
    let breaksCompleted: Int
    let breaksSkipped: Int
    
    /// The ratio of completed breaks to scheduled breaks, from 0.0 to 1.0.
    var complianceRate: Double {
        guard breaksScheduled > 0 else { return 1.0 } // Avoid division by zero
        return Double(breaksCompleted) / Double(breaksScheduled)
    }
    
    /// A formatted string for the compliance rate (e.g., "95%").
    var compliancePercentage: String {
        return String(format: "%.0f%%", complianceRate * 100)
    }
}

/// A summary of analytics over a specific time range (e.g., weekly, monthly).
struct AnalyticsSummary: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let dailyStats: [DailyStats]
    
    /// Total work time over the period.
    var totalWorkTime: TimeInterval {
        return dailyStats.reduce(0) { $0 + $1.totalWorkTime }
    }
    
    /// Total break time over the period.
    var totalBreakTime: TimeInterval {
        return dailyStats.reduce(0) { $0 + $1.totalBreakTime }
    }
    
    /// Total number of breaks scheduled.
    var totalBreaksScheduled: Int {
        return dailyStats.reduce(0) { $0 + $1.breaksScheduled }
    }
    
    /// Total number of breaks completed.
    var totalBreaksCompleted: Int {
        return dailyStats.reduce(0) { $0 + $1.breaksCompleted }
    }
    
    /// Total number of breaks skipped.
    var totalBreaksSkipped: Int {
        return dailyStats.reduce(0) { $0 + $1.breaksSkipped }
    }
    
    /// Average compliance rate over the period.
    var averageComplianceRate: Double {
        guard !dailyStats.isEmpty else { return 1.0 }
        let totalRate = dailyStats.reduce(0) { $0 + $1.complianceRate }
        return totalRate / Double(dailyStats.count)
    }
}

/// Represents a streak of consecutive days where the user met their break goals.
struct BreakStreak: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let streakStartDate: Date?
    
    /// A description of the current streak.
    var streakDescription: String {
        if currentStreak > 1 {
            return "\(currentStreak) days in a row!"
        } else if currentStreak == 1 {
            return "First day of a new streak!"
        } else {
            return "No active streak. Let's start one!"
        }
    }
} 