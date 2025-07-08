//
//  Extensions.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Date Extensions

extension Date {
    
    /// Get the start of the day for this date
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// Get the end of the day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// Check if this date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Check if this date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// Check if this date is in the current week
    var isThisWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Get a relative string description (e.g., "2 minutes ago", "Tomorrow")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format date for display in break statistics
    var statisticsDisplayString: String {
        let formatter = DateFormatter()
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isThisWeek {
            formatter.dateFormat = "EEEE" // Day of week
        } else {
            formatter.dateFormat = "MMM d" // Short month and day
        }
        return formatter.string(from: self)
    }
    
    /// Format time only (e.g., "2:30 PM")
    var timeDisplayString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Add a time interval and return a new date
    func adding(minutes: Int) -> Date {
        return addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    func adding(seconds: Int) -> Date {
        return addingTimeInterval(TimeInterval(seconds))
    }
    
    /// Get the number of days between two dates
    func daysBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: otherDate.startOfDay)
        return abs(components.day ?? 0)
    }
    
    /// Check if this date falls within work hours based on hour and minute
    func isWithinWorkHours(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        return currentMinutes >= startMinutes && currentMinutes <= endMinutes
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    
    /// Convert time interval to minutes
    var minutes: Int {
        return Int(self / 60)
    }
    
    /// Convert time interval to hours
    var hours: Double {
        return self / 3600
    }
    
    /// Format time interval as a readable string (e.g., "5m 30s", "1h 15m")
    var formattedString: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else if minutes > 0 {
            if seconds > 0 && minutes < 5 { // Show seconds for short durations
                return "\(minutes)m \(seconds)s"
            } else {
                return "\(minutes)m"
            }
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Format time interval for countdown display (e.g., "05:30", "1:05:30")
    var countdownString: String {
        let totalSeconds = Int(abs(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Create a TimeInterval from minutes
    static func minutes(_ value: Int) -> TimeInterval {
        return TimeInterval(value * 60)
    }
    
    /// Create a TimeInterval from hours
    static func hours(_ value: Double) -> TimeInterval {
        return TimeInterval(value * 3600)
    }
}

// MARK: - String Extensions

extension String {
    
    /// Localized string helper
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
    
    /// Capitalize first letter only
    var capitalizedFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }
    
    /// Check if string is a valid bundle identifier
    var isValidBundleIdentifier: Bool {
        let regex = try? NSRegularExpression(pattern: "^[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)*$")
        let range = NSRange(location: 0, length: self.count)
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
}

// MARK: - Color Extensions

extension Color {
    
    /// Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Get hex string representation of color
    var hexString: String {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
    
    /// Blend with another color
    func blended(with other: Color, ratio: Double) -> Color {
        let clampedRatio = max(0, min(1, ratio))
        let inverseRatio = 1 - clampedRatio
        
        let selfNSColor = NSColor(self)
        let otherNSColor = NSColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        selfNSColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherNSColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return Color(
            red: Double(r1 * CGFloat(inverseRatio) + r2 * CGFloat(clampedRatio)),
            green: Double(g1 * CGFloat(inverseRatio) + g2 * CGFloat(clampedRatio)),
            blue: Double(b1 * CGFloat(inverseRatio) + b2 * CGFloat(clampedRatio)),
            opacity: Double(a1 * CGFloat(inverseRatio) + a2 * CGFloat(clampedRatio))
        )
    }
}

// MARK: - Array Extensions

extension Array {
    
    /// Safe subscript that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// Remove all occurrences of element
    mutating func removeAll(where predicate: (Element) throws -> Bool) rethrows {
        self = try filter { try !predicate($0) }
    }
}

extension Array where Element: Equatable {
    
    /// Remove first occurrence of element
    mutating func removeFirst(_ element: Element) {
        if let index = firstIndex(of: element) {
            remove(at: index)
        }
    }
    
    /// Remove all occurrences of element
    mutating func removeAll(_ element: Element) {
        removeAll { $0 == element }
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    
    /// Set value for SettingsKeys enum
    func set<T>(_ value: T, for key: String) {
        set(value, forKey: key)
    }
    
    /// Get value for SettingsKeys enum with default
    func value<T>(for key: String, defaultValue: T) -> T {
        return object(forKey: key) as? T ?? defaultValue
    }
    
    /// Remove value for SettingsKeys enum
    func removeValue(for key: String) {
        removeObject(forKey: key)
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    
    /// App version string
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// App build number
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// App display name
    var appDisplayName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? 
               infoDictionary?["CFBundleName"] as? String ?? "Work Mate"
    }
    
    /// Bundle identifier
    var bundleID: String {
        return bundleIdentifier ?? "com.workmate.app"
    }
}

// MARK: - NSApplication Extensions

#if canImport(AppKit)
import AppKit

extension NSApplication {
    
    /// Get the frontmost application
    var frontmostApp: NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }
    
    /// Check if the current app is the frontmost
    var isCurrentAppFrontmost: Bool {
        return frontmostApp?.bundleIdentifier == Bundle.main.bundleIdentifier
    }
    
    /// Bring the app to front
    func bringToFront() {
        activate(ignoringOtherApps: true)
    }
}

#endif

// MARK: - Notification Extensions

extension Notification.Name {
    
    // Work Mate specific notifications
    static let breakScheduled = Notification.Name("BreakScheduled")
    static let breakStarted = Notification.Name("BreakStarted")
    static let breakCompleted = Notification.Name("BreakCompleted")
    static let breakSkipped = Notification.Name("BreakSkipped")
    static let breakPaused = Notification.Name("BreakPaused")
    static let breakResumed = Notification.Name("BreakResumed")
    static let settingsChanged = Notification.Name("SettingsChanged")
    static let activityStatusChanged = Notification.Name("ActivityStatusChanged")
    static let permissionsChanged = Notification.Name("PermissionsChanged")
}

// MARK: - CGFloat Extensions

extension CGFloat {
    
    /// Convert degrees to radians
    var degreesToRadians: CGFloat {
        return self * .pi / 180
    }
    
    /// Convert radians to degrees
    var radiansToDegrees: CGFloat {
        return self * 180 / .pi
    }
}

// MARK: - Double Extensions

extension Double {
    
    /// Round to specified decimal places
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    /// Convert to percentage string
    var percentageString: String {
        return String(format: "%.1f%%", self * 100)
    }
    
    /// Clamp value between min and max
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

// MARK: - View Extensions

extension View {
    
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply modifier only on certain conditions
    @ViewBuilder
    func conditionalModifier<Content: View>(
        _ condition: Bool,
        modifier: (Self) -> Content
    ) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
    
    /// Add border with conditional color
    func border(_ color: Color, width: CGFloat = 1, condition: Bool = true) -> some View {
        if condition {
            return AnyView(self.overlay(RoundedRectangle(cornerRadius: 0).stroke(color, lineWidth: width)))
        } else {
            return AnyView(self)
        }
    }
} 