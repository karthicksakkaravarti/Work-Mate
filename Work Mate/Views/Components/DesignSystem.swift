//
//  DesignSystem.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

// MARK: - Color Palette
/// Defines the application's color scheme.
/// Note: Custom colors should be defined in the asset catalog (`Assets.xcassets`).
enum AppColor {
    // Primary Colors
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryGreen = Color("PrimaryGreen")
    static let primaryRed = Color("PrimaryRed")

    // Neutral Colors
    static let systemBackground = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    
    static let labelPrimary = Color(nsColor: .labelColor)
    static let labelSecondary = Color(nsColor: .secondaryLabelColor)
    static let labelTertiary = Color(nsColor: .tertiaryLabelColor)
    
    // Semantic Colors
    static let success = Color("SuccessGreen")
    static let warning = Color("WarningOrange")
    static let error = Color("ErrorRed")
}

// MARK: - Typography
/// Defines the text styles used throughout the application.
enum AppFont {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.medium)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption.weight(.medium)
}

// MARK: - Spacing
/// Defines standard spacing units for layout consistency.
enum AppSpacing {
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
}

// MARK: - Corner Radius
/// Defines standard corner radius values for UI elements.
enum AppCornerRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
}

// MARK: - Animation
/// Defines standard animations for UI transitions.
enum AppAnimation {
    static let subtle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let medium = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let responsive = Animation.spring(response: 0.3, dampingFraction: 0.6)
} 