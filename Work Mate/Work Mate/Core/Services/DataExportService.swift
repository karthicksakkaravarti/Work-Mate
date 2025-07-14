//
//  DataExportService.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation

/// Defines the formats available for data export.
enum ExportFormat {
    case json
    case csv
}

/// A service for exporting user analytics data.
class DataExportService {
    private let analyticsService: AnalyticsService
    
    /// Initializes the service with an analytics service instance.
    /// - Parameter analyticsService: The service used to fetch analytics data.
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    /// Exports all daily statistics within a given date range.
    /// - Parameters:
    ///   - format: The desired export format (`.json` or `.csv`).
    ///   - dateRange: The range of dates to include in the export.
    /// - Returns: A `Data` object containing the exported content, or `nil` on failure.
    func exportData(format: ExportFormat, for dateRange: ClosedRange<Date>) async -> Data? {
        let summary = await analyticsService.getAnalyticsSummary(for: dateRange)
        let dailyStats = summary.dailyStats
        
        switch format {
        case .json:
            return exportToJSON(stats: dailyStats)
        case .csv:
            return exportToCSV(stats: dailyStats)
        }
    }
    
    // MARK: - Private Export Methods
    
    /// Converts an array of `DailyStats` to JSON data.
    private func exportToJSON(stats: [DailyStats]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(stats)
        } catch {
            print("Failed to export analytics to JSON: \(error)")
            return nil
        }
    }
    
    /// Converts an array of `DailyStats` to CSV data.
    private func exportToCSV(stats: [DailyStats]) -> Data? {
        var csvString = "date,totalWorkTime,totalBreakTime,breaksScheduled,breaksCompleted,breaksSkipped,complianceRate\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for stat in stats {
            let date = dateFormatter.string(from: stat.date)
            let row = "\(date),\(stat.totalWorkTime),\(stat.totalBreakTime),\(stat.breaksScheduled),\(stat.breaksCompleted),\(stat.breaksSkipped),\(stat.complianceRate)\n"
            csvString.append(row)
        }
        
        return csvString.data(using: .utf8)
    }
} 