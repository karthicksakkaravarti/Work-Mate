//
//  CustomButton.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// Defines the visual style of a `CustomButton`.
enum ButtonStyleType {
    case primary
    case secondary
    case destructive
}

/// A custom `ButtonStyle` that applies app-specific styling.
struct CustomButtonStyle: ButtonStyle {
    let styleType: ButtonStyleType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundColor(foregroundColor)
            .background(backgroundColor(for: configuration))
            .cornerRadius(AppCornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.subtle, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch styleType {
        case .secondary:
            return AppColor.labelPrimary
        default:
            return .white
        }
    }
    
    private func backgroundColor(for configuration: Configuration) -> Color {
        let baseColor: Color
        switch styleType {
        case .primary:
            baseColor = AppColor.primaryBlue
        case .secondary:
            baseColor = AppColor.secondaryBackground
        case .destructive:
            baseColor = AppColor.primaryRed
        }
        return configuration.isPressed ? baseColor.opacity(0.8) : baseColor
    }
}

/// A reusable, styled button component for the app.
struct CustomButton: View {
    let title: String
    let style: ButtonStyleType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(CustomButtonStyle(styleType: style))
    }
}

struct CustomButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.spacing16) {
            CustomButton(title: "Primary Action", style: .primary, action: {})
            CustomButton(title: "Secondary Action", style: .secondary, action: {})
            CustomButton(title: "Destructive Action", style: .destructive, action: {})
        }
        .padding()
        .frame(width: 300)
    }
} 