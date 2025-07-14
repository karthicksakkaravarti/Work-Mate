//
//  StatusMenuView.swift
//  Work Mate
//
//  Created by Work Mate on 2024-01-01.
//

import SwiftUI

/// A view containing the menu items for secondary actions like settings and quitting.
struct StatusMenuView: View {
    // These would be connected to environment objects or a state manager
    @State private var isSchedulerPaused = false
    
    var body: some View {
        VStack {
            // Pause/Resume Toggle
            Toggle(isOn: $isSchedulerPaused) {
                Label("Pause Scheduler", systemImage: isSchedulerPaused ? "play.circle.fill" : "pause.circle.fill")
            }
            .toggleStyle(.button)
            .tint(isSchedulerPaused ? AppColor.primaryGreen : AppColor.warning)
            
            Divider()
            
            // Menu Buttons
            Button(action: {
                // Action to open settings
            }) {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.plain)
            
            Button(action: {
                // Action to open analytics/stats
            }) {
                Label("Statistics", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("Quit Work Mate", systemImage: "power.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }
}

struct StatusMenuView_Previews: PreviewProvider {
    static var previews: some View {
        StatusMenuView()
            .padding()
            .frame(width: 250)
    }
} 