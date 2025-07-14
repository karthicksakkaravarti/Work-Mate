//
//  MenuBarManager.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI
import Combine

/// Manages the state and interactions for the menu bar interface.
@MainActor
class MenuBarManager: ObservableObject {
    // MARK: - Published Properties
    @Published var appStatus: AppStatus = .active
    @Published var timeUntilNextBreak: TimeInterval = 0
    @Published var nextBreakType: String = "Micro Break"
    @Published var progress: Double = 0
    
    // MARK: - Private Properties
    private let breakScheduler: BreakScheduler
    private var cancellables = Set<AnyCancellable>()
    
    /// Initializes the manager and sets up bindings to the break scheduler.
    /// - Parameter breakScheduler: The application's central break scheduling service.
    init(breakScheduler: BreakScheduler) {
        self.breakScheduler = breakScheduler
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func startBreak() {
        // Placeholder for starting a break manually
        print("Start Break button tapped")
    }
    
    func skipBreak() {
        // Placeholder for skipping the next break
        print("Skip Break button tapped")
    }
    
    func togglePause() {
        // Placeholder for pausing/resuming the scheduler
        let isPaused = appStatus == .paused
        print("Toggling pause: \(isPaused ? "Resuming" : "Pausing")")
    }
    
    func openSettings() {
        // Placeholder for opening the settings window
        print("Open Settings tapped")
    }
    
    func openStatistics() {
        // Placeholder for opening the statistics window
        print("Open Statistics tapped")
    }
    
    // MARK: - Private Methods
    
    /// Binds to the `BreakScheduler`'s published properties to keep the UI in sync.
    private func setupBindings() {
        // Example binding (these would be adjusted to match actual scheduler properties)
        breakScheduler.$nextBreak
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nextBreak in
                guard let self = self, let scheduledBreak = nextBreak else { return }
                
                self.timeUntilNextBreak = scheduledBreak.scheduledTime.timeIntervalSinceNow
                self.nextBreakType = scheduledBreak.type.displayName
                
                // Calculate progress
                let totalDuration = scheduledBreak.type.defaultInterval
                self.progress = 1.0 - (self.timeUntilNextBreak / totalDuration)
            }
            .store(in: &cancellables)
            
        breakScheduler.$schedulerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.appStatus = state.isPaused ? .paused : .active
            }
            .store(in: &cancellables)
    }
} 