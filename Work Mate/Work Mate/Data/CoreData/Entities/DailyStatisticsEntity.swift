//
//  DailyStatisticsEntity.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import CoreData

/// Core Data entity for storing daily statistics.
public class DailyStatisticsEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var totalWorkTime: TimeInterval
    @NSManaged public var totalBreakTime: TimeInterval
    @NSManaged public var breaksScheduled: Int32
    @NSManaged public var breaksCompleted: Int32
    @NSManaged public var breaksSkipped: Int32
    
    // Relationship to BreakSessionEntity (if needed)
    // @NSManaged public var breakSessions: NSSet?
}

extension DailyStatisticsEntity {
    /// Creates a fetch request for this entity.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyStatisticsEntity> {
        return NSFetchRequest<DailyStatisticsEntity>(entityName: "DailyStatisticsEntity")
    }
} 