//
//  CalendarIntegration.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import EventKit

/// Calendar integration service for detecting meetings and events
@MainActor
class CalendarIntegration: ObservableObject {
    
    // MARK: - Published Properties
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var currentEvents: [EKEvent] = []
    @Published var upcomingEvents: [EKEvent] = []
    
    // MARK: - Private Properties
    private let eventStore: EKEventStore
    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = 60 // Check every minute
    
    // MARK: - Configuration
    private let lookAheadMinutes: TimeInterval = 30 * 60 // Look ahead 30 minutes
    private let eventBufferMinutes: TimeInterval = 5 * 60 // 5 minute buffer before/after events
    
    // MARK: - Initialization
    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        
        setupNotifications()
    }
    
    deinit {
        // Clean up timer directly since we can't call main actor methods from deinit
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring calendar events
    func startMonitoring() {
        guard authorizationStatus == .fullAccess else {
            print("Calendar access not granted, cannot start monitoring")
            return
        }
        
        stopMonitoring() // Stop any existing monitoring
        
        // Initial update
        updateCurrentEvents()
        
        // Start periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentEvents()
            }
        }
        
        print("Calendar monitoring started")
    }
    
    /// Stop monitoring calendar events
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("Calendar monitoring stopped")
    }
    
    /// Get current calendar conflicts that would interfere with breaks
    func getCurrentConflicts() -> [EKEvent] {
        return currentEvents.filter { event in
            isEventActiveNow(event) && shouldAvoidDuringEvent(event)
        }
    }
    
    /// Get the next available time slot for a break
    func getNextAvailableSlot() -> Date? {
        let now = Date()
        let futureLimit = now.addingTimeInterval(lookAheadMinutes)
        
        // Get all events in the next 30 minutes
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: futureLimit,
            calendars: nil
        )
        
        let futureEvents = eventStore.events(matching: predicate)
            .filter { shouldAvoidDuringEvent($0) }
            .sorted { $0.startDate < $1.startDate }
        
        // If no upcoming events, break can happen now
        if futureEvents.isEmpty {
            return now
        }
        
        // Find gaps between events
        var lastEndTime = now
        
        for event in futureEvents {
            let eventStart = event.startDate.addingTimeInterval(-eventBufferMinutes)
            
            // Check if there's a gap of at least 10 minutes
            if eventStart.timeIntervalSince(lastEndTime) >= 10 * 60 {
                return lastEndTime
            }
            
            if let eventEndDate = event.endDate {
                lastEndTime = max(lastEndTime, eventEndDate.addingTimeInterval(eventBufferMinutes))
            }
        }
        
        // Return time after all events
        return lastEndTime
    }
    
    /// Check if there's an active meeting or important event
    func hasActiveMeeting() -> Bool {
        return getCurrentConflicts().contains { event in
            isMeetingEvent(event) && isEventActiveNow(event)
        }
    }
    
    /// Get the current active meeting, if any
    func getCurrentMeeting() -> EKEvent? {
        return getCurrentConflicts().first { event in
            isMeetingEvent(event) && isEventActiveNow(event)
        }
    }
    
    /// Request calendar permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    self.startMonitoring()
                }
            }
            return granted
        } catch {
            print("Error requesting calendar permission: \(error)")
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for calendar database changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDatabaseChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
        
        // Listen for authorization changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EKEventStoreAuthorizationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.authorizationStatusChanged()
        }
    }
    
    @objc private func calendarDatabaseChanged() {
        Task { @MainActor in
            updateCurrentEvents()
        }
    }
    
    private func authorizationStatusChanged() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        
        if authorizationStatus == .fullAccess {
            startMonitoring()
        } else {
            stopMonitoring()
            currentEvents = []
            upcomingEvents = []
        }
    }
    
    private func updateCurrentEvents() {
        guard authorizationStatus == .fullAccess else {
            return
        }
        
        let now = Date()
        let endTime = now.addingTimeInterval(lookAheadMinutes)
        
        // Create predicate for events in the time window
        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-eventBufferMinutes),
            end: endTime,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        // Separate current and upcoming events
        let current = events.filter { isEventActiveNow($0) }
        let upcoming = events.filter { $0.startDate > now && $0.startDate <= endTime }
        
        // Update published properties
        self.currentEvents = current.sorted { $0.startDate < $1.startDate }
        self.upcomingEvents = upcoming.sorted { $0.startDate < $1.startDate }
        
        // Debug logging
        if !current.isEmpty {
            print("Active calendar events: \(current.map { $0.title ?? "Untitled" })")
        }
    }
    
    private func isEventActiveNow(_ event: EKEvent) -> Bool {
        let now = Date()
        let bufferedStart = event.startDate.addingTimeInterval(-eventBufferMinutes)
        
        guard let eventEndDate = event.endDate else {
            return false // If no end date, can't determine if active
        }
        
        let bufferedEnd = eventEndDate.addingTimeInterval(eventBufferMinutes)
        
        return now >= bufferedStart && now <= bufferedEnd
    }
    
    private func shouldAvoidDuringEvent(_ event: EKEvent) -> Bool {
        // Skip all-day events
        if event.isAllDay {
            return false
        }
        
        // Skip events marked as free time
        if event.availability == .free {
            return false
        }
        
        // Skip declined events
        if event.attendees?.contains(where: { $0.participantStatus == .declined }) == true {
            return false
        }
        
        // Avoid events with certain keywords
        let title = event.title?.lowercased() ?? ""
        let meetingKeywords = ["meeting", "call", "interview", "presentation", "demo", "standup", "scrum", "sync"]
        
        for keyword in meetingKeywords {
            if title.contains(keyword) {
                return true
            }
        }
        
        // Avoid events with attendees (likely meetings)
        if let attendees = event.attendees, !attendees.isEmpty {
            return true
        }
        
        // Avoid events marked as busy
        if event.availability == .busy {
            return true
        }
        
        // Default to avoiding the event if we're unsure
        return true
    }
    
    private func isMeetingEvent(_ event: EKEvent) -> Bool {
        // Check if event has attendees
        if let attendees = event.attendees, !attendees.isEmpty {
            return true
        }
        
        // Check for meeting-related keywords in title
        let title = event.title?.lowercased() ?? ""
        let meetingKeywords = ["meeting", "call", "interview", "standup", "scrum", "sync"]
        
        return meetingKeywords.contains { title.contains($0) }
    }
}

// MARK: - Extensions

extension CalendarIntegration {
    
    /// Get a summary of the current calendar state
    var statusSummary: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Calendar access not requested"
        case .denied, .restricted:
            return "Calendar access denied"
        case .fullAccess:
            if currentEvents.isEmpty {
                return "No active events"
            } else {
                let count = currentEvents.count
                return "\(count) active event\(count == 1 ? "" : "s")"
            }
        case .writeOnly:
            return "Limited calendar access"
        @unknown default:
            return "Unknown calendar status"
        }
    }
    
    /// Get the next meeting description
    var nextMeetingDescription: String? {
        guard let nextMeeting = upcomingEvents.first(where: { isMeetingEvent($0) }) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: nextMeeting.startDate)
        
        return "\(nextMeeting.title ?? "Meeting") at \(timeString)"
    }
} 