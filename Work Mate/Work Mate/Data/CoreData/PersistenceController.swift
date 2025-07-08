//
//  PersistenceController.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import CoreData
import SwiftUI

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // MARK: - Core Data Stack
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WorkMate")
        
        // Configure store description
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                print("Core Data failed to load: \(error), \(error.userInfo)")
                
                // In production, you might want to:
                // 1. Show user-friendly error message
                // 2. Attempt to recover by deleting and recreating the store
                // 3. Report the error to analytics service
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton pattern
    }
    
    // MARK: - Save Context
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("Core Data context saved successfully")
            } catch {
                print("Failed to save Core Data context: \(error)")
                // Handle the error appropriately in production
            }
        }
    }
    
    // MARK: - Background Context Operations
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                let result = block(context)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Data Management
    
    func deleteAllData() {
        let context = container.viewContext
        
        // Get all entity names
        let entityNames = ["BreakSession", "DailyStatistics", "UserPreferences"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }
        
        save()
    }
    
    func exportData() -> Data? {
        let context = container.viewContext
        
        do {
            // Fetch all break sessions
            let sessionRequest: NSFetchRequest<BreakSession> = BreakSession.fetchRequest()
            let sessions = try context.fetch(sessionRequest)
            
            // Fetch all daily statistics
            let statsRequest: NSFetchRequest<DailyStatistics> = DailyStatistics.fetchRequest()
            let stats = try context.fetch(statsRequest)
            
            // Create export data structure
            let exportData: [String: Any] = [
                "exportDate": Date(),
                "version": "1.0",
                "breakSessions": sessions.map { session in
                    [
                        "id": session.id?.uuidString ?? "",
                        "startTime": session.startTime ?? Date(),
                        "endTime": session.endTime ?? Date(),
                        "breakType": session.breakType ?? "",
                        "scheduledDuration": session.scheduledDuration,
                        "actualDuration": session.actualDuration,
                        "wasCompleted": session.wasCompleted,
                        "wasSkipped": session.wasSkipped,
                        "skipReason": session.skipReason ?? ""
                    ]
                },
                "dailyStatistics": stats.map { stat in
                    [
                        "id": stat.id?.uuidString ?? "",
                        "date": stat.date ?? Date(),
                        "totalWorkTime": stat.totalWorkTime,
                        "totalBreakTime": stat.totalBreakTime,
                        "breaksScheduled": stat.breaksScheduled,
                        "breaksCompleted": stat.breaksCompleted,
                        "breaksSkipped": stat.breaksSkipped,
                        "complianceRate": stat.complianceRate,
                        "longestWorkStreak": stat.longestWorkStreak
                    ]
                }
            ]
            
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }
    
    // MARK: - Migration Support
    
    func migrateIfNeeded() {
        // This method can be extended to handle data migrations
        // when the Core Data model changes in future versions
        print("Checking for Core Data migrations...")
    }
    
    // MARK: - Preview Support
    
    static var preview: PersistenceController = {
        let controller = PersistenceController()
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let sampleSession = BreakSession(context: context)
        sampleSession.id = UUID()
        sampleSession.startTime = Date()
        sampleSession.endTime = Date().addingTimeInterval(30)
        sampleSession.breakType = "micro"
        sampleSession.scheduledDuration = 30
        sampleSession.actualDuration = 30
        sampleSession.wasCompleted = true
        sampleSession.wasSkipped = false
        sampleSession.createdAt = Date()
        
        let sampleStats = DailyStatistics(context: context)
        sampleStats.id = UUID()
        sampleStats.date = Date()
        sampleStats.totalWorkTime = 8 * 3600 // 8 hours
        sampleStats.totalBreakTime = 300 // 5 minutes
        sampleStats.breaksScheduled = 48 // Every 10 minutes for 8 hours
        sampleStats.breaksCompleted = 40
        sampleStats.breaksSkipped = 8
        sampleStats.complianceRate = 0.83 // 83%
        sampleStats.longestWorkStreak = 25 * 60 // 25 minutes
        
        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
} 