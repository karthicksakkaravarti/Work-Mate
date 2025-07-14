//
//  BreakTimerView.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// A view that displays a formatted time interval, for use in countdowns.
struct BreakTimerView: View {
    let timeRemaining: TimeInterval
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Text(formattedTime)
            .font(AppFont.title1.monospacedDigit())
            .foregroundColor(AppColor.labelPrimary)
            .padding(.horizontal, AppSpacing.spacing16)
            .padding(.vertical, AppSpacing.spacing8)
            .background(AppColor.secondaryBackground)
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct BreakTimerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.spacing20) {
            BreakTimerView(timeRemaining: 125)
            BreakTimerView(timeRemaining: 3600)
        }
        .padding()
    }
} 