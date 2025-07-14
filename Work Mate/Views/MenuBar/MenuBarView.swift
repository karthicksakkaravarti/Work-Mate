//
//  MenuBarView.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// The main interface view that appears when clicking the menu bar icon.
struct MenuBarView: View {
    // These would be connected to a state manager or environment objects
    @State private var timeUntilNextBreak: TimeInterval = 24 * 60 + 30
    @State private var nextBreakType: String = "Micro Break"
    @State private var progress: Double = 0.4
    
    var body: some View {
        VStack(spacing: AppSpacing.spacing16) {
            // Header
            Text("Next Break")
                .font(AppFont.headline)
                .foregroundColor(AppColor.labelSecondary)
            
            // Progress and Timer
            ZStack {
                ProgressCircle(progress: progress, color: AppColor.primaryBlue, lineWidth: 10)
                
                VStack {
                    Text(nextBreakType)
                        .font(AppFont.title2)
                        .foregroundColor(AppColor.labelPrimary)
                    
                    BreakTimerView(timeRemaining: timeUntilNextBreak)
                }
            }
            .frame(width: 180, height: 180)
            
            // Action Buttons
            VStack(spacing: AppSpacing.spacing8) {
                CustomButton(title: "Start Break Now", style: .primary, action: {
                    // Action to start break
                })
                
                CustomButton(title: "Skip Next Break", style: .secondary, action: {
                    // Action to skip break
                })
            }
            
            Divider()
            
            // Status Menu
            StatusMenuView()
            
        }
        .padding(AppSpacing.spacing16)
        .frame(width: 280)
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
    }
} 