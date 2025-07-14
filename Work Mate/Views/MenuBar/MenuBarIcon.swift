//
//  MenuBarIcon.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// The current state of the application, used to determine the menu bar icon.
enum AppStatus {
    case active
    case onBreak
    case paused
}

/// A dynamic menu bar icon that reflects the application's status.
struct MenuBarIcon: View {
    let status: AppStatus
    
    private var iconName: String {
        switch status {
        case .active:
            return "clock"
        case .onBreak:
            return "cup.and.saucer.fill"
        case .paused:
            return "pause.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .active:
            return AppColor.primaryBlue
        case .onBreak:
            return AppColor.primaryGreen
        case .paused:
            return AppColor.warning
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.system(size: 16, weight: .medium))
    }
}

struct MenuBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: AppSpacing.spacing20) {
            MenuBarIcon(status: .active)
            MenuBarIcon(status: .onBreak)
            MenuBarIcon(status: .paused)
        }
        .padding()
    }
} 