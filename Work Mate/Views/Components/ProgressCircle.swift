//
//  ProgressCircle.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// A circular view that shows progress, often used for timers.
struct ProgressCircle: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    /// Initializes a progress circle.
    /// - Parameters:
    ///   - progress: The progress value, from 0.0 to 1.0.
    ///   - color: The color of the progress ring.
    ///   - lineWidth: The thickness of the progress ring.
    init(progress: Double, color: Color = AppColor.primaryBlue, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Foreground progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // Start from the top
                .animation(AppAnimation.subtle, value: progress)
        }
        .padding(lineWidth / 2)
    }
}

struct ProgressCircle_Previews: PreviewProvider {
    static var previews: some View {
        ProgressCircle(progress: 0.75, color: AppColor.primaryGreen, lineWidth: 12)
            .frame(width: 150, height: 150)
            .padding()
    }
} 