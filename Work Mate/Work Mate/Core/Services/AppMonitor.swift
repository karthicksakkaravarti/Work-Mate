//
//  AppMonitor.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import AppKit

/// Application monitoring service for detecting active apps and system states
@MainActor
class AppMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var frontmostApplication: NSRunningApplication?
    @Published var isFullscreenActive: Bool = false
    @Published var isPresentationMode: Bool = false
    @Published var isDoNotDisturbActive: Bool = false
    @Published var activeApplications: [NSRunningApplication] = []
    
    // MARK: - Private Properties
    private let workspace: NSWorkspace
    nonisolated private let observers_lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = 5 // Check every 5 seconds
    
    // MARK: - Known Application Bundle Identifiers
    private let presentationApps = [
        "com.apple.keynote",
        "com.microsoft.Powerpoint",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan", // Google Slides
        "com.prezi.PreziNext",
        "com.slides.app",
        "com.deckset.Deckset"
    ]
    
    private let videoConferenceApps = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.skype.skype",
        "com.google.Chrome.app.knipolnnllmklapflnccelgolnpehhpl", // Google Meet
        "com.cisco.webexmeetingsapp",
        "com.gotomeeting.GoToMeetingHD",
        "com.bluejeans.BlueJeansApp"
    ]
    
    private let fullscreenSensitiveApps = [
        "com.apple.QuickTimePlayerX",
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.apple.TV",
        "com.netflix.Netflix",
        "com.spotify.client"
    ]
    
    // MARK: - Initialization
    init(workspace: NSWorkspace = NSWorkspace.shared) {
        self.workspace = workspace
        self.frontmostApplication = workspace.frontmostApplication
        
        setupInitialState()
        setupNotificationObservers()
    }
    
    deinit {
        // Clean up timer directly since we can't call main actor methods from deinit
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Perform observer cleanup in a non-isolated way
        observers_lock.lock()
        defer { observers_lock.unlock() }
        
        observers.forEach { observer in
            workspace.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring application changes and system states
    func startMonitoring() {
        stopMonitoring() // Stop any existing monitoring
        
        // Initial state update
        updateApplicationState()
        updateSystemState()
        
        // Start periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemState()
            }
        }
        
        print("Application monitoring started")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("Application monitoring stopped")
    }
    
    /// Check if a fullscreen app is currently active
    func isFullscreenAppActive() -> Bool {
        guard let frontmost = frontmostApplication else { return false }
        
        // Check if it's a known fullscreen-sensitive app
        let bundleId = frontmost.bundleIdentifier ?? ""
        if fullscreenSensitiveApps.contains(bundleId) {
            return true
        }
        
        // Check if any window is in fullscreen mode
        return isFullscreenActive
    }
    
    /// Check if presentation mode is currently active
    func isPresentationModeActive() -> Bool {
        guard let frontmost = frontmostApplication else { return false }
        
        let bundleId = frontmost.bundleIdentifier ?? ""
        
        // Check if it's a known presentation app
        if presentationApps.contains(bundleId) {
            return true
        }
        
        // Check if it's a video conference app
        if videoConferenceApps.contains(bundleId) {
            return true
        }
        
        // Check if we detected presentation mode through other means
        return isPresentationMode
    }
    
    /// Get the current frontmost application
    func getCurrentApplication() -> NSRunningApplication? {
        return frontmostApplication
    }
    
    /// Check if a specific app is currently active
    func isAppActive(bundleIdentifier: String) -> Bool {
        return frontmostApplication?.bundleIdentifier == bundleIdentifier
    }
    
    /// Get all running applications
    func getRunningApplications() -> [NSRunningApplication] {
        return workspace.runningApplications
    }
    
    /// Check if an app is blacklisted for breaks
    func isBlacklistedAppActive(blacklist: Set<String>) -> Bool {
        guard let bundleId = frontmostApplication?.bundleIdentifier else { return false }
        return blacklist.contains(bundleId)
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        frontmostApplication = workspace.frontmostApplication
        activeApplications = workspace.runningApplications
        updateSystemState()
    }
    
    private func setupNotificationObservers() {
        let notificationCenter = workspace.notificationCenter
        
        // Application activation
        let activationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationActivation(notification)
        }
        observers.append(activationObserver)
        
        // Application deactivation
        let deactivationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationDeactivation(notification)
        }
        observers.append(deactivationObserver)
        
        // Application launch
        let launchObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationLaunch(notification)
        }
        observers.append(launchObserver)
        
        // Application termination
        let terminationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationTermination(notification)
        }
        observers.append(terminationObserver)
        
        // Screen parameters changed (for fullscreen detection)
        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFullscreenState()
            }
        }
        observers.append(screenObserver)
    }
    
    private func removeObservers() {
        observers_lock.lock()
        defer { observers_lock.unlock() }
        
        observers.forEach { observer in
            workspace.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
    
    private func handleApplicationActivation(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            frontmostApplication = app
            updateApplicationState()
            
            print("App activated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "Unknown"))")
        }
    }
    
    private func handleApplicationDeactivation(_ notification: Notification) {
        updateApplicationState()
    }
    
    private func handleApplicationLaunch(_ notification: Notification) {
        updateApplicationState()
    }
    
    private func handleApplicationTermination(_ notification: Notification) {
        updateApplicationState()
    }
    
    private func updateApplicationState() {
        frontmostApplication = workspace.frontmostApplication
        activeApplications = workspace.runningApplications
        
        // Update presentation mode based on current app
        updatePresentationModeState()
    }
    
    private func updateSystemState() {
        updateFullscreenState()
        updateDoNotDisturbState()
        updatePresentationModeState()
    }
    
    private func updateFullscreenState() {
        // Check if any application window is in fullscreen mode
        var isFullscreen = false
        
        // Use CGWindowListCopyWindowInfo to check for fullscreen windows
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                   let width = bounds["Width"],
                   let height = bounds["Height"] {
                    
                    // Check if window covers the entire screen
                    if let screen = NSScreen.main {
                        let screenFrame = screen.frame
                        if width >= screenFrame.width && height >= screenFrame.height {
                            isFullscreen = true
                            break
                        }
                    }
                }
            }
        }
        
        isFullscreenActive = isFullscreen
    }
    
    private func updateDoNotDisturbState() {
        // Check Do Not Disturb status
        // Note: This is a simplified check. In reality, macOS doesn't provide a direct API for DND status
        // We can infer it from notification center state or user preferences
        
        // For now, we'll use a heuristic approach
        // This would need to be enhanced with private APIs or system preferences monitoring
        
        // Placeholder implementation
        isDoNotDisturbActive = false
    }
    
    private func updatePresentationModeState() {
        guard let frontmost = frontmostApplication else {
            isPresentationMode = false
            return
        }
        
        let bundleId = frontmost.bundleIdentifier ?? ""
        
        // Check if it's a known presentation app
        if presentationApps.contains(bundleId) {
            isPresentationMode = true
            return
        }
        
        // Check if it's a video conference app
        if videoConferenceApps.contains(bundleId) {
            isPresentationMode = true
            return
        }
        
        // Check for fullscreen state with presentation-sensitive apps
        if isFullscreenActive && fullscreenSensitiveApps.contains(bundleId) {
            isPresentationMode = true
            return
        }
        
        isPresentationMode = false
    }
}

// MARK: - Extensions

extension AppMonitor {
    
    /// Get a human-readable description of the current application state
    var statusDescription: String {
        guard let app = frontmostApplication else {
            return "No active application"
        }
        
        let appName = app.localizedName ?? "Unknown App"
        var status = "Active: \(appName)"
        
        if isFullscreenActive {
            status += " (Fullscreen)"
        }
        
        if isPresentationMode {
            status += " (Presentation)"
        }
        
        if isDoNotDisturbActive {
            status += " (DND)"
        }
        
        return status
    }
    
    /// Get the bundle identifier of the current app
    var currentAppBundleId: String? {
        return frontmostApplication?.bundleIdentifier
    }
    
    /// Check if the current app is likely a work-focused application
    var isWorkApp: Bool {
        guard let bundleId = currentAppBundleId else { return false }
        
        let workApps = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.jetbrains.intellij",
            "com.sublimetext.4",
            "com.microsoft.teams",
            "com.slack.Slack",
            "com.figma.Desktop",
            "com.adobe.Creative",
            "com.microsoft.Excel",
            "com.microsoft.Word",
            "com.microsoft.Powerpoint"
        ]
        
        return workApps.contains { bundleId.contains($0) }
    }
} 