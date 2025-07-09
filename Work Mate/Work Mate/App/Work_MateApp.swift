//
//  Work_MateApp.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import SwiftUI

@main
struct Work_MateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Core Data persistence controller
    let persistenceController = PersistenceController.shared
    
    // Settings manager
    @StateObject private var settingsManager = SettingsManager.shared
    
    // Permission manager
    @StateObject private var permissionManager = PermissionManager.shared
    
    // Activity monitor
    @StateObject private var activityMonitor = ActivityMonitor()
    
    // Break scheduler
    @StateObject private var breakScheduler: BreakScheduler
    
    // Core state objects that will be created in later steps
    @StateObject private var appState = AppState()
    
    init() {
        // Initialize BreakScheduler with dependencies
        let activityMonitor = ActivityMonitor()
        let breakScheduler = BreakScheduler(activityMonitor: activityMonitor)
        
        _activityMonitor = StateObject(wrappedValue: activityMonitor)
        _breakScheduler = StateObject(wrappedValue: breakScheduler)
    }
    
    var body: some Scene {
        // MenuBar application instead of regular window
        MenuBarExtra("Work Mate", systemImage: "clock") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(permissionManager)
                .environmentObject(activityMonitor)
                .environmentObject(breakScheduler)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window that can be opened when needed
        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(permissionManager)
                .environmentObject(activityMonitor)
                .environmentObject(breakScheduler)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
        .defaultPosition(.center)
    }
}

// Temporary placeholder for AppState - will be properly implemented in Step 18
@MainActor
class AppState: ObservableObject {
    @Published var isBreakActive: Bool = false
    @Published var timeUntilNextBreak: TimeInterval = 600 // 10 minutes default
    @Published var currentBreakType: BreakType?
    
    func updateFromBreakScheduler(_ breakScheduler: BreakScheduler) {
        isBreakActive = breakScheduler.isBreakActive
        timeUntilNextBreak = breakScheduler.timeUntilNextBreak
        currentBreakType = breakScheduler.currentBreak?.type
    }
}

// Temporary placeholder views - will be properly implemented in later steps
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var activityMonitor: ActivityMonitor
    @EnvironmentObject var breakScheduler: BreakScheduler
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Work Mate")
                .font(.headline)
            
            // Scheduler Status
            HStack {
                Image(systemName: schedulerStatusIcon)
                    .foregroundColor(schedulerStatusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(breakScheduler.schedulerState.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    if !permissionManager.requiredPermissionsGranted {
                        Text("Permissions needed")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
            }
            
            if !permissionManager.requiredPermissionsGranted {
                Button("Grant Permissions") {
                    Task {
                        await activityMonitor.requestPermissions()
                    }
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
            } else {
                Divider()
                
                // Break Status Section
                if breakScheduler.isBreakActive {
                    VStack(spacing: 4) {
                        Text("Break Active")
                            .font(.caption)
                            .foregroundColor(.orange)
                        if let currentBreak = breakScheduler.currentBreak {
                            Text(currentBreak.type.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Button("Skip") {
                                breakScheduler.skipCurrentBreak()
                            }
                            .controlSize(.mini)
                            
                            if let currentBreak = breakScheduler.currentBreak {
                                if currentBreak.status == .paused {
                                    Button("Resume") {
                                        breakScheduler.resumeCurrentBreak()
                                    }
                                    .controlSize(.mini)
                                } else {
                                    Button("Pause") {
                                        breakScheduler.pauseCurrentBreak()
                                    }
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                } else {
                    // Next Break Information
                    VStack(spacing: 4) {
                        if let nextBreakType = breakScheduler.nextBreakType {
                            HStack {
                                Text("Next \(nextBreakType.displayName):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTimeInterval(breakScheduler.timeUntilNextBreak))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(nextBreakType == .micro ? .blue : .green)
                            }
                        }
                        
                        if breakScheduler.nextMicroBreak != nil {
                            HStack {
                                Text("Micro break interval:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(settingsManager.microBreakInterval) min")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if breakScheduler.nextRegularBreak != nil {
                            HStack {
                                Text("Regular break interval:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(settingsManager.regularBreakInterval) min")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Quick Actions
                    HStack {
                        Button("Micro Break") {
                            breakScheduler.triggerBreak(type: .micro)
                        }
                        .controlSize(.mini)
                        
                        Button("Regular Break") {
                            breakScheduler.triggerBreak(type: .regular)
                        }
                        .controlSize(.mini)
                    }
                    
                    // Scheduler Controls
                    HStack {
                        if breakScheduler.schedulerState == .running {
                            Button("Pause") {
                                breakScheduler.pauseScheduling()
                            }
                            .controlSize(.mini)
                        } else if breakScheduler.schedulerState == .paused {
                            Button("Resume") {
                                breakScheduler.resumeScheduling()
                            }
                            .controlSize(.mini)
                        } else {
                            Button("Start") {
                                breakScheduler.startScheduling()
                            }
                            .controlSize(.mini)
                        }
                        
                        if breakScheduler.schedulerState != .stopped {
                            Button("Stop") {
                                breakScheduler.stopScheduling()
                            }
                            .controlSize(.mini)
                        }
                    }
                }
                
                Divider()
                
                // Activity Status
                HStack {
                    Image(systemName: activityStatusIcon)
                        .foregroundColor(activityStatusColor)
                        .font(.caption)
                    Text(activityMonitor.statusDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: settingsManager.soundEnabled ? "speaker.2" : "speaker.slash")
                        .foregroundColor(settingsManager.soundEnabled ? .primary : .secondary)
                        .font(.caption)
                    Text(settingsManager.overlayTypeEnum.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            Divider()
            
            Button("Settings") {
                openSettings()
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            // Start services if permissions are granted
            if permissionManager.requiredPermissionsGranted {
                activityMonitor.startMonitoring()
                breakScheduler.startScheduling()
            }
        }
        .onDisappear {
            // Services continue running in background
        }
    }
    
    private var schedulerStatusIcon: String {
        switch breakScheduler.schedulerState {
        case .running:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .disabled:
            return "xmark.circle.fill"
        }
    }
    
    private var schedulerStatusColor: Color {
        switch breakScheduler.schedulerState {
        case .running:
            return .green
        case .paused:
            return .orange
        case .stopped:
            return .red
        case .disabled:
            return .gray
        }
    }
    
    private var activityStatusIcon: String {
        switch activityMonitor.currentStatus {
        case .active:
            return "person.fill"
        case .inactive:
            return "person.fill.questionmark"
        case .away:
            return "person.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var activityStatusColor: Color {
        switch activityMonitor.currentStatus {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .away:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func openSettings() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Open new settings window
            NSApp.sendAction(#selector(NSApplicationDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:)), to: NSApp.delegate, from: nil)
        }
    }
}

struct SettingsWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var activityMonitor: ActivityMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Work Mate Settings")
                .font(.title)
                .padding(.bottom)
            
            // Permissions Section
            GroupBox("Permissions & Activity Monitoring") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PermissionType.allCases, id: \.self) { permissionType in
                        HStack {
                            Image(systemName: permissionIcon(for: permissionType))
                                .foregroundColor(permissionColor(for: permissionType))
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(permissionType.displayName)
                                    .font(.caption)
                                Text(permissionType.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(permissionManager.status(for: permissionType).displayName)
                                .font(.caption)
                                .foregroundColor(permissionColor(for: permissionType))
                            
                            if !permissionManager.isGranted(permissionType) && permissionType.isRequired {
                                Button("Grant") {
                                    permissionManager.openSystemPreferences(for: permissionType)
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .controlSize(.mini)
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Activity Status:")
                        Spacer()
                        Text(activityMonitor.statusDescription)
                            .foregroundColor(activityMonitor.isUserActive ? .green : .orange)
                    }
                    
                    if permissionManager.requiredPermissionsGranted {
                        HStack {
                            Toggle("Enable Activity Monitoring", isOn: .constant(activityMonitor.isMonitoring))
                                .disabled(true) // Always on when permissions are granted
                            
                            Spacer()
                            
                            Button("Test Activity") {
                                #if DEBUG
                                activityMonitor.simulateActivity()
                                #endif
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .controlSize(.mini)
                        }
                    }
                }
                .padding()
            }
            
            GroupBox("Break Intervals") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Micro break interval:")
                        Spacer()
                        Stepper("\(settingsManager.microBreakInterval) minutes", 
                               value: $settingsManager.microBreakInterval, 
                               in: 5...30, 
                               step: 5)
                    }
                    
                    HStack {
                        Text("Micro break duration:")
                        Spacer()
                        Stepper("\(settingsManager.microBreakDuration) seconds", 
                               value: $settingsManager.microBreakDuration, 
                               in: 15...120, 
                               step: 15)
                    }
                    
                    HStack {
                        Text("Regular break interval:")
                        Spacer()
                        Stepper("\(settingsManager.regularBreakInterval) minutes", 
                               value: $settingsManager.regularBreakInterval, 
                               in: 30...120, 
                               step: 15)
                    }
                    
                    HStack {
                        Text("Regular break duration:")
                        Spacer()
                        Stepper(TimeInterval.minutes(settingsManager.regularBreakDuration / 60).formattedString, 
                               value: $settingsManager.regularBreakDuration, 
                               in: 120...900, 
                               step: 60)
                    }
                }
                .padding()
            }
            
            GroupBox("Break Behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overlay Type:")
                        Spacer()
                        Picker("Overlay Type", selection: $settingsManager.overlayTypeEnum) {
                            ForEach(OverlayType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Toggle("Smart scheduling", isOn: $settingsManager.enableSmartScheduling)
                    
                    HStack {
                        Toggle("Pause on inactivity", isOn: $settingsManager.pauseOnInactivity)
                        
                        if settingsManager.pauseOnInactivity {
                            Spacer()
                            Stepper("After \(settingsManager.inactivityThreshold) seconds",
                                   value: $settingsManager.inactivityThreshold,
                                   in: 30...300,
                                   step: 30)
                                .onChange(of: settingsManager.inactivityThreshold) { _ in
                                    activityMonitor.updateConfigFromSettings()
                                }
                        }
                    }
                    
                    Toggle("Enable sounds", isOn: $settingsManager.soundEnabled)
                }
                .padding()
            }
            
            HStack {
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
                    activityMonitor.updateConfigFromSettings()
                }
                .buttonStyle(BorderedButtonStyle())
                
                Spacer()
                
                Text("Settings are automatically saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 550, minHeight: 700)
        .onAppear {
            activityMonitor.updateConfigFromSettings()
        }
    }
    
    private func permissionIcon(for type: PermissionType) -> String {
        let status = permissionManager.status(for: type)
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notRequested:
            return "questionmark.circle"
        case .restricted:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "circle"
        }
    }
    
    private func permissionColor(for type: PermissionType) -> Color {
        let status = permissionManager.status(for: type)
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notRequested:
            return .blue
        case .restricted:
            return .orange
        case .unknown:
            return .gray
        }
    }
}
