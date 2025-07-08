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
    
    // Core state objects that will be created in later steps
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // MenuBar application instead of regular window
        MenuBarExtra("Work Mate", systemImage: "clock") {
            MenuBarView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window that can be opened when needed
        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(appState)
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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Work Mate")
                .font(.headline)
            
            if appState.isBreakActive {
                Text("Break in progress...")
                    .foregroundColor(.orange)
            } else {
                Text("Next break in \(Int(appState.timeUntilNextBreak / 60)) min")
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
        .frame(width: 200)
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
    
    var body: some View {
        VStack {
            Text("Work Mate Settings")
                .font(.title)
                .padding()
            
            Text("Settings interface will be implemented in later steps")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}
