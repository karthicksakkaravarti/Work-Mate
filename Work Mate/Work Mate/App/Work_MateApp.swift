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
    
    // Core state objects that will be created in later steps
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // MenuBar application instead of regular window
        MenuBarExtra("Work Mate", systemImage: "clock") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(permissionManager)
                .environmentObject(activityMonitor)
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
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
        .defaultPosition(.center)
    }
}

// Temporary placeholder for AppState - will be properly implemented in Step 18
class AppState: ObservableObject {
    @Published var isBreakActive: Bool = false
    @Published var timeUntilNextBreak: TimeInterval = 600 // 10 minutes default
}

// Temporary placeholder views - will be properly implemented in later steps
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var activityMonitor: ActivityMonitor
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Work Mate")
                .font(.headline)
            
            // Activity Status
            HStack {
                Image(systemName: activityStatusIcon)
                    .foregroundColor(activityStatusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activityMonitor.statusDescription)
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
                
                if appState.isBreakActive {
                    Text("Break in progress...")
                        .foregroundColor(.orange)
                } else {
                    HStack {
                        Text("Next micro break:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(settingsManager.microBreakInterval) min")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Next regular break:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(settingsManager.regularBreakInterval) min")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: settingsManager.soundEnabled ? "speaker.2" : "speaker.slash")
                        .foregroundColor(settingsManager.soundEnabled ? .primary : .secondary)
                    Text(settingsManager.overlayTypeEnum.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .frame(width: 250)
        .onAppear {
            // Start activity monitoring if permissions are granted
            if permissionManager.requiredPermissionsGranted {
                activityMonitor.startMonitoring()
            }
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
