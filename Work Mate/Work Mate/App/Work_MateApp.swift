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
    
    // Core state objects that will be created in later steps
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // MenuBar application instead of regular window
        MenuBarExtra("Work Mate", systemImage: "clock") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window that can be opened when needed
        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(appState)
                .environmentObject(settingsManager)
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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Work Mate")
                .font(.headline)
            
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
            
            Divider()
            
            Button("Settings") {
                openSettings()
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Work Mate Settings")
                .font(.title)
                .padding(.bottom)
            
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
                    Toggle("Pause on inactivity", isOn: $settingsManager.pauseOnInactivity)
                    Toggle("Enable sounds", isOn: $settingsManager.soundEnabled)
                }
                .padding()
            }
            
            HStack {
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
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
        .frame(minWidth: 500, minHeight: 600)
    }
}
