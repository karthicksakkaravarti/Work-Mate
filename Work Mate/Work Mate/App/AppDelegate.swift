//
//  AppDelegate.swift
//  Work Mate
//
//  Created by Karthick Sakkaravarthi on 08/07/25.
//

import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app for menubar-only operation
        setupMenuBarApp()
        
        // Hide from dock since this is a menubar app
        NSApp.setActivationPolicy(.accessory)
        
        // Register for system notifications
        registerForSystemNotifications()
        
        print("Work Mate started successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup before app terminates
        print("Work Mate terminating...")
        // TODO: Save any pending data, stop timers, etc. in future steps
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle reopen events (when user clicks dock icon if shown, or other triggers)
        if !flag {
            // No visible windows, so open settings window
            openSettingsWindow()
        }
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupMenuBarApp() {
        // Prevent the app from appearing in Cmd+Tab switcher
        NSApp.setActivationPolicy(.accessory)
        
        // Disable window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    private func registerForSystemNotifications() {
        // Register for system sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Register for session changes (user switching, login/logout)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionDidResignActive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
    }
    
    private func openSettingsWindow() {
        // This will be improved when we implement proper settings window management
        // For now, we'll rely on the WindowGroup defined in Work_MateApp.swift
        print("Opening settings window")
    }
    
    // MARK: - System Event Handlers
    
    @objc private func systemWillSleep() {
        print("System going to sleep - pausing break timers")
        // TODO: Pause break timers and save state (implement in later steps)
    }
    
    @objc private func systemDidWake() {
        print("System woke up - resuming break timers")
        // TODO: Resume break timers and restore state (implement in later steps)
    }
    
    @objc private func sessionDidBecomeActive() {
        print("User session became active - resuming monitoring")
        // TODO: Resume activity monitoring (implement in later steps)
    }
    
    @objc private func sessionDidResignActive() {
        print("User session resigned active - pausing monitoring")
        // TODO: Pause activity monitoring (implement in later steps)
    }
}

// MARK: - Menu Actions

extension AppDelegate {
    @objc func openSettings() {
        openSettingsWindow()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
} 