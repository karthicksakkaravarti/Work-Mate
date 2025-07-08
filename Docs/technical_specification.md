# Work Mate Technical Specification

## 1. System Overview

### Core Purpose and Value Proposition
Work Mate is a native macOS menubar application designed to promote healthy work habits by providing intelligent break reminders. The app helps users maintain productivity while reducing physical strain and mental fatigue through customizable break schedules and smart interruption management.

### Key Workflows
1. **Break Scheduling**: Continuous monitoring of work time with configurable intervals
2. **Break Execution**: Display overlay screens with break activities and controls
3. **Smart Interruption Management**: Detect inappropriate times for breaks and reschedule
4. **Activity Monitoring**: Track user engagement and break compliance
5. **Settings Management**: Persistent storage and synchronization of user preferences

### System Architecture
- **Presentation Layer**: SwiftUI views for menubar interface and break overlays
- **Business Logic Layer**: Break scheduling engine, activity detection, and smart logic
- **Data Layer**: Core Data for persistence, UserDefaults for simple settings
- **Integration Layer**: EventKit for calendar, ScreenTime API for app detection
- **Background Services**: NSTimer-based scheduling, NSWorkspace monitoring

## 2. Project Structure

```
Work Mate/
├── Work Mate/
│   ├── App/
│   │   ├── Work_MateApp.swift              # Main app entry point
│   │   └── AppDelegate.swift               # System integration and lifecycle
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── BreakSession.swift          # Break session data model
│   │   │   ├── UserSettings.swift          # User preferences model
│   │   │   └── BreakStatistics.swift       # Analytics data model
│   │   ├── Services/
│   │   │   ├── BreakScheduler.swift        # Core scheduling logic
│   │   │   ├── ActivityMonitor.swift       # User activity detection
│   │   │   ├── SmartScheduling.swift       # Intelligent break timing
│   │   │   └── AnalyticsService.swift      # Statistics tracking
│   │   └── Utilities/
│   │       ├── NotificationManager.swift   # System notifications
│   │       ├── PermissionManager.swift     # System permissions
│   │       └── Extensions.swift            # Swift extensions
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift           # Main menubar interface
│   │   │   └── StatusMenuView.swift        # Dropdown menu
│   │   ├── BreakOverlay/
│   │   │   ├── BreakOverlayWindow.swift    # Full-screen overlay window
│   │   │   ├── BreakContentView.swift      # Break activity content
│   │   │   └── BreakControlsView.swift     # Break control buttons
│   │   ├── Settings/
│   │   │   ├── SettingsWindow.swift        # Settings window container
│   │   │   ├── GeneralSettingsView.swift   # General preferences
│   │   │   ├── SchedulingSettingsView.swift # Break scheduling options
│   │   │   └── AnalyticsSettingsView.swift # Analytics preferences
│   │   └── Components/
│   │       ├── BreakTimerView.swift        # Countdown timer component
│   │       ├── ProgressIndicator.swift     # Progress visualization
│   │       └── BreakActivityViews.swift    # Break activity components
│   ├── Data/
│   │   ├── CoreData/
│   │   │   ├── WorkMate.xcdatamodeld       # Core Data model
│   │   │   └── PersistenceController.swift # Core Data stack
│   │   └── UserDefaults/
│   │       └── SettingsKeys.swift          # UserDefaults keys
│   ├── Resources/
│   │   ├── Assets.xcassets/                # Images and colors
│   │   ├── Localizable.strings             # Localization
│   │   └── Sounds/                         # Notification sounds
│   └── Supporting Files/
│       ├── Info.plist                      # App configuration
│       └── Work_Mate.entitlements          # App permissions
├── Work MateTests/                         # Unit tests
└── Work MateUITests/                       # UI automation tests
```

## 3. Feature Specification

### 3.1 Break Reminder System
**User Story**: As a user, I want to receive regular break reminders to maintain healthy work habits.

**Implementation Steps**:
1. Initialize `BreakScheduler` service on app launch
2. Configure timer intervals based on user settings (micro-breaks: 10min, regular breaks: 60min)
3. Monitor user activity through `NSWorkspace` and `CGEventSource`
4. Trigger break notifications when intervals elapse and user is active
5. Display appropriate break overlay based on configured break type

**Error Handling**:
- Handle system sleep/wake cycles by pausing/resuming timers
- Gracefully handle permission denials for system monitoring
- Fallback to basic timer if activity detection fails

### 3.2 Break Overlay System
**User Story**: As a user, I want different types of break interfaces that suit my workflow needs.

**Implementation Steps**:
1. Create `NSWindow` subclass for overlay display with appropriate window level
2. Implement three overlay modes:
   - Full screen: `NSWindow.Level.screenSaver` with opaque background
   - Partial: `NSWindow.Level.floating` with semi-transparent overlay
   - Notification: Native `NSUserNotification` with action buttons
3. Add break content views with breathing exercises, stretches, or motivational content
4. Implement control buttons (skip, pause, snooze) with proper state management

**Error Handling**:
- Handle multiple monitor setups by displaying on active screen
- Ensure overlay dismisses properly on system events
- Prevent overlay from blocking critical system dialogs

### 3.3 Smart Scheduling
**User Story**: As a user, I want breaks to avoid interrupting important activities like meetings or presentations.

**Implementation Steps**:
1. Integrate with `EventKit` to access calendar data
2. Monitor active applications using `NSWorkspace.shared.frontmostApplication`
3. Detect full-screen applications and presentation modes
4. Implement break delay logic when blacklisted apps are active
5. Queue missed breaks and reschedule appropriately

**Error Handling**:
- Handle calendar permission denials gracefully
- Provide manual override options for smart scheduling
- Ensure breaks aren't indefinitely delayed

### 3.4 Activity Monitoring
**User Story**: As a user, I want the break timer to pause when I'm not actively working.

**Implementation Steps**:
1. Monitor keyboard and mouse input using `CGEventSource.secondsSinceLastEventType`
2. Implement inactivity threshold (default: 2 minutes)
3. Pause break timers during inactivity periods
4. Resume timers when activity resumes
5. Store activity patterns for analytics

**Error Handling**:
- Handle accessibility permission requirements
- Provide fallback behavior if monitoring fails
- Respect privacy by not logging specific input events

### 3.5 Analytics and Statistics
**User Story**: As a user, I want to track my break habits and see progress over time.

**Implementation Steps**:
1. Create `BreakStatistics` Core Data entity with daily aggregations
2. Track metrics: breaks taken, breaks skipped, total work time, compliance rate
3. Implement streak calculation logic
4. Create visualization components using Charts framework
5. Export data functionality for user analysis

**Error Handling**:
- Handle Core Data migration for schema updates
- Ensure analytics don't impact app performance
- Provide data reset options for privacy

## 4. Database Schema

### 4.1 Core Data Entities

#### BreakSession
```swift
entity BreakSession {
    @NSManaged var id: UUID
    @NSManaged var startTime: Date
    @NSManaged var endTime: Date?
    @NSManaged var scheduledDuration: Int32
    @NSManaged var actualDuration: Int32
    @NSManaged var breakType: String // "micro", "regular", "custom"
    @NSManaged var wasCompleted: Bool
    @NSManaged var wasSkipped: Bool
    @NSManaged var skipReason: String?
    @NSManaged var createdAt: Date
}
```

#### DailyStatistics
```swift
entity DailyStatistics {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var totalWorkTime: Int32
    @NSManaged var totalBreakTime: Int32
    @NSManaged var breaksScheduled: Int32
    @NSManaged var breaksCompleted: Int32
    @NSManaged var breaksSkipped: Int32
    @NSManaged var complianceRate: Float
    @NSManaged var longestWorkStreak: Int32
    @NSManaged var breakSessions: Set<BreakSession>
}
```

#### UserPreferences
```swift
entity UserPreferences {
    @NSManaged var id: UUID
    @NSManaged var microBreakInterval: Int32 // minutes
    @NSManaged var microBreakDuration: Int32 // seconds
    @NSManaged var regularBreakInterval: Int32 // minutes
    @NSManaged var regularBreakDuration: Int32 // seconds
    @NSManaged var overlayType: String // "full", "partial", "notification"
    @NSManaged var workStartTime: Date
    @NSManaged var workEndTime: Date
    @NSManaged var enableSmartScheduling: Bool
    @NSManaged var blacklistedApps: [String]
    @NSManaged var soundEnabled: Bool
    @NSManaged var selectedSoundtrack: String?
    @NSManaged var lastModified: Date
}
```

### 4.2 Relationships and Indexes
- `DailyStatistics` → `BreakSession` (one-to-many)
- Index on `DailyStatistics.date` for quick day-based queries
- Index on `BreakSession.startTime` for chronological sorting
- Unique constraint on `DailyStatistics.date` to prevent duplicates

## 5. Services and Core Logic

### 5.1 BreakScheduler Service
```swift
class BreakScheduler: ObservableObject {
    func startScheduling()
    func pauseScheduling()
    func resetTimers()
    func scheduleNextBreak(type: BreakType, delay: TimeInterval?)
    func handleBreakCompletion(session: BreakSession)
    func handleBreakSkip(reason: SkipReason)
}
```

**Core Operations**:
- Maintain separate timers for micro and regular breaks
- Calculate next break time based on user activity and preferences
- Queue break requests when smart scheduling delays are active
- Persist break sessions to Core Data upon completion

### 5.2 ActivityMonitor Service
```swift
class ActivityMonitor: ObservableObject {
    func startMonitoring()
    func stopMonitoring()
    func getInactivityDuration() -> TimeInterval
    func isUserActive() -> Bool
    func requestAccessibilityPermissions()
}
```

**Core Operations**:
- Use `CGEventSource` to monitor system input events
- Implement activity threshold detection (configurable sensitivity)
- Provide real-time activity status updates
- Handle permission requests and status monitoring

### 5.3 SmartScheduling Service
```swift
class SmartScheduling: ObservableObject {
    func shouldDelayBreak() -> Bool
    func getDelayReason() -> DelayReason?
    func checkCalendarConflicts() -> [EKEvent]
    func isBlacklistedAppActive() -> Bool
    func estimateNextAvailableTime() -> Date?
}
```

**Core Operations**:
- Integration with `EventKit` for calendar event detection
- Monitor frontmost application and window states
- Detect presentation/fullscreen modes
- Calculate optimal break reschedule times

### 5.4 AnalyticsService
```swift
class AnalyticsService: ObservableObject {
    func recordBreakSession(_ session: BreakSession)
    func calculateDailyStats(for date: Date) -> DailyStatistics
    func getWeeklyTrend() -> [DailyStatistics]
    func calculateStreakCount() -> Int
    func exportData(format: ExportFormat) -> Data
}
```

**Core Operations**:
- Aggregate break session data into daily statistics
- Calculate compliance rates and streak metrics
- Generate trend analysis and insights
- Export user data in JSON/CSV formats

## 6. Design System

### 6.1 Visual Style

#### Color Palette
```swift
// Primary Colors
static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)      // #007AFF
static let primaryGreen = Color(red: 0.20, green: 0.78, blue: 0.35)   // #34C759
static let primaryRed = Color(red: 1.0, green: 0.23, blue: 0.19)      // #FF3B30

// Neutral Colors
static let systemBackground = Color(.systemBackground)
static let secondaryBackground = Color(.secondarySystemBackground)
static let tertiaryBackground = Color(.tertiarySystemBackground)
static let labelPrimary = Color(.labelColor)
static let labelSecondary = Color(.secondaryLabelColor)

// Semantic Colors
static let successGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
static let warningOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
static let errorRed = Color(red: 1.0, green: 0.23, blue: 0.19)
```

#### Typography
```swift
// System Font Hierarchy
static let largeTitle = Font.largeTitle.weight(.bold)
static let title1 = Font.title.weight(.semibold)
static let title2 = Font.title2.weight(.medium)
static let headline = Font.headline.weight(.semibold)
static let body = Font.body
static let callout = Font.callout
static let caption = Font.caption.weight(.medium)
```

#### Spacing and Layout
```swift
// Standard Spacing Units
static let spacing4: CGFloat = 4
static let spacing8: CGFloat = 8
static let spacing12: CGFloat = 12
static let spacing16: CGFloat = 16
static let spacing20: CGFloat = 20
static let spacing24: CGFloat = 24
static let spacing32: CGFloat = 32

// Corner Radius
static let cornerRadiusSmall: CGFloat = 6
static let cornerRadiusMedium: CGFloat = 10
static let cornerRadiusLarge: CGFloat = 16
```

### 6.2 Core Components

#### MenuBarIcon Component
```swift
struct MenuBarIcon: View {
    @State var isBreakActive: Bool
    @State var timeUntilBreak: TimeInterval
    
    var body: some View {
        Image(systemName: isBreakActive ? "pause.circle.fill" : "clock")
            .foregroundColor(isBreakActive ? .primaryRed : .primaryBlue)
            .font(.system(size: 16, weight: .medium))
    }
}
```

#### BreakOverlay Component
```swift
struct BreakOverlay: View {
    @Binding var breakSession: BreakSession
    let overlayType: OverlayType
    
    var body: some View {
        ZStack {
            backgroundOverlay
            VStack(spacing: spacing24) {
                breakContent
                breakControls
            }
        }
    }
}
```

#### ProgressCircle Component
```swift
struct ProgressCircle: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat = 8
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
```

## 7. Component Architecture

### 7.1 View Hierarchy and Data Flow

#### Main App Structure
```swift
@main
struct WorkMateApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var breakScheduler = BreakScheduler()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        MenuBarExtra("Work Mate", systemImage: "clock") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(breakScheduler)
                .environmentObject(settingsManager)
        }
        .menuBarExtraStyle(.window)
        
        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(settingsManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
    }
}
```

#### State Management Pattern
```swift
class AppState: ObservableObject {
    @Published var currentBreakSession: BreakSession?
    @Published var isBreakActive: Bool = false
    @Published var timeUntilNextBreak: TimeInterval = 0
    @Published var dailyStats: DailyStatistics?
    @Published var permissionStatus: PermissionStatus = .unknown
}
```

### 7.2 Service Integration Pattern
```swift
class BreakScheduler: ObservableObject {
    @Published var isSchedulingActive: Bool = false
    private let activityMonitor: ActivityMonitor
    private let smartScheduling: SmartScheduling
    private let analyticsService: AnalyticsService
    
    init() {
        self.activityMonitor = ActivityMonitor()
        self.smartScheduling = SmartScheduling()
        self.analyticsService = AnalyticsService()
        setupScheduling()
    }
}
```

## 8. Background Services and System Integration

### 8.1 Timer Management
```swift
class TimerManager: ObservableObject {
    private var microBreakTimer: Timer?
    private var regularBreakTimer: Timer?
    private var activityCheckTimer: Timer?
    
    func startTimers(microInterval: TimeInterval, regularInterval: TimeInterval)
    func pauseTimers()
    func resumeTimers()
    func invalidateAllTimers()
}
```

### 8.2 System Event Handling
```swift
class SystemEventManager: NSObject {
    func registerForSystemEvents()
    func handleSystemWake()
    func handleSystemSleep()
    func handleUserSessionChange()
    func handleDisplayConfigurationChange()
}
```

### 8.3 Permission Management
```swift
class PermissionManager: ObservableObject {
    @Published var accessibilityPermission: PermissionStatus = .unknown
    @Published var calendarPermission: PermissionStatus = .unknown
    @Published var notificationPermission: PermissionStatus = .unknown
    
    func requestAllPermissions()
    func checkAccessibilityPermission() -> Bool
    func openSystemPreferences(for permission: PermissionType)
}
```

## 9. Data Persistence and Settings

### 9.1 Core Data Stack
```swift
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WorkMate")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    func save()
    func deleteAllData()
    func exportData() -> Data?
}
```

### 9.2 Settings Management
```swift
class SettingsManager: ObservableObject {
    @AppStorage("microBreakInterval") var microBreakInterval: Int = 10
    @AppStorage("microBreakDuration") var microBreakDuration: Int = 30
    @AppStorage("regularBreakInterval") var regularBreakInterval: Int = 60
    @AppStorage("regularBreakDuration") var regularBreakDuration: Int = 300
    @AppStorage("overlayType") var overlayType: String = "partial"
    @AppStorage("smartSchedulingEnabled") var smartSchedulingEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    
    func resetToDefaults()
    func exportSettings() -> [String: Any]
    func importSettings(from data: [String: Any])
}
```

## 10. Accessibility and Internationalization

### 10.1 Accessibility Implementation
```swift
// VoiceOver support for break overlays
struct AccessibleBreakOverlay: View {
    var body: some View {
        VStack {
            Text("Break time")
                .accessibilityLabel("Break reminder is active")
                .accessibilityHint("Take a moment to rest and recharge")
            
            BreakTimerView()
                .accessibilityLabel("Break timer")
                .accessibilityValue("\(remainingTime) seconds remaining")
                
            HStack {
                Button("Skip Break") { }
                    .accessibilityHint("Skip this break and continue working")
                Button("Pause Break") { }
                    .accessibilityHint("Pause the break timer temporarily")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
```

### 10.2 Localization Support
```swift
// Localizable.strings
"break.micro.title" = "Micro Break";
"break.regular.title" = "Regular Break";
"break.skip.button" = "Skip Break";
"break.pause.button" = "Pause Break";
"settings.general.title" = "General Settings";
"settings.scheduling.title" = "Break Scheduling";
"analytics.compliance.label" = "Break Compliance";
"permissions.accessibility.required" = "Accessibility permission required";
```

## 11. Security and Privacy

### 11.1 Data Privacy Implementation
```swift
class PrivacyManager: ObservableObject {
    @Published var analyticsEnabled: Bool = true
    @Published var calendarAccessEnabled: Bool = false
    @Published var activityMonitoringEnabled: Bool = true
    
    func clearAllUserData()
    func exportUserData() -> Data?
    func getDataUsageReport() -> DataUsageReport
}
```

### 11.2 Optional iCloud Sync
```swift
class CloudSyncManager: ObservableObject {
    @Published var iCloudSyncEnabled: Bool = false
    @Published var syncStatus: SyncStatus = .disabled
    
    func enableiCloudSync()
    func disableiCloudSync()
    func syncSettingsToCloud()
    func syncSettingsFromCloud()
}
```

## 12. Testing Strategy

### 12.1 Unit Tests with XCTest
```swift
class BreakSchedulerTests: XCTestCase {
    var scheduler: BreakScheduler!
    var mockActivityMonitor: MockActivityMonitor!
    
    override func setUp() {
        mockActivityMonitor = MockActivityMonitor()
        scheduler = BreakScheduler(activityMonitor: mockActivityMonitor)
    }
    
    func testMicroBreakScheduling() {
        // Test micro break timer initialization
        scheduler.startScheduling()
        XCTAssertTrue(scheduler.isSchedulingActive)
        
        // Test break triggering after interval
        mockActivityMonitor.simulateActivity()
        scheduler.simulateTimeElapsed(minutes: 10)
        XCTAssertNotNil(scheduler.currentBreakSession)
    }
    
    func testSmartSchedulingDelay() {
        // Test break delay during calendar conflicts
        let mockEvent = MockCalendarEvent(title: "Important Meeting")
        scheduler.smartScheduling.addMockEvent(mockEvent)
        
        scheduler.triggerBreak(type: .micro)
        XCTAssertTrue(scheduler.isBreakDelayed)
        XCTAssertEqual(scheduler.delayReason, .calendarConflict)
    }
}
```

### 12.2 UI Tests with XCTest
```swift
class WorkMateUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    func testBreakOverlayInteraction() {
        // Simulate break trigger
        app.menuBars.statusItems["Work Mate"].click()
        app.menuItems["Trigger Break Now"].click()
        
        // Verify overlay appears
        let breakOverlay = app.windows["Break Overlay"]
        XCTAssertTrue(breakOverlay.exists)
        
        // Test skip functionality
        let skipButton = breakOverlay.buttons["Skip Break"]
        XCTAssertTrue(skipButton.exists)
        skipButton.click()
        
        // Verify overlay dismisses
        XCTAssertFalse(breakOverlay.exists)
    }
    
    func testSettingsNavigation() {
        // Open settings from menu bar
        app.menuBars.statusItems["Work Mate"].click()
        app.menuItems["Settings"].click()
        
        // Navigate through settings tabs
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.exists)
        
        settingsWindow.buttons["Scheduling"].click()
        XCTAssertTrue(settingsWindow.staticTexts["Break Intervals"].exists)
        
        settingsWindow.buttons["Analytics"].click()
        XCTAssertTrue(settingsWindow.staticTexts["Daily Statistics"].exists)
    }
}
```

### 12.3 Performance Testing
```swift
class PerformanceTests: XCTestCase {
    func testBreakSchedulerPerformance() {
        let scheduler = BreakScheduler()
        
        measure {
            // Test performance of break scheduling logic
            for _ in 0..<1000 {
                scheduler.calculateNextBreakTime()
            }
        }
    }
    
    func testCoreDataPerformance() {
        let context = PersistenceController.shared.container.viewContext
        
        measure {
            // Test performance of analytics data insertion
            for i in 0..<100 {
                let session = BreakSession(context: context)
                session.id = UUID()
                session.startTime = Date()
                session.breakType = "micro"
            }
            try! context.save()
        }
    }
}
```

## 13. Deployment and Distribution

### 13.1 App Store Configuration
```xml
<!-- Info.plist configuration -->
<key>LSUIElement</key>
<true/>  <!-- Run as background app -->

<key>NSAppleEventsUsageDescription</key>
<string>Work Mate needs to monitor system activity to provide accurate break timing.</string>

<key>NSCalendarsUsageDescription</key>
<string>Work Mate can integrate with your calendar to avoid interrupting meetings.</string>

<key>NSUserNotificationsUsageDescription</key>
<string>Work Mate sends break reminders and notifications.</string>
```

### 13.2 Sandboxing and Entitlements
```xml
<!-- Work_Mate.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>  <!-- For optional cloud sync -->
<key>com.apple.security.personal-information.calendars</key>
<true/>
```

### 13.3 Code Signing and Notarization
- Configure automatic signing with development team
- Implement build scripts for notarization process
- Set up CI/CD pipeline for automated testing and deployment
- Configure crash reporting and analytics collection (opt-in only)

This specification provides a comprehensive foundation for implementing the Work Mate macOS application with all required features, proper architecture patterns, and testing strategies. The modular design allows for incremental development and future feature additions while maintaining code quality and user privacy. 