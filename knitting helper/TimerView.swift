//
//  TimerView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @State private var showResetConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Running indicator - static circle
            Circle()
                .fill(timerViewModel.isRunning ? Color("AccentColor") : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            // Timer display
            Text(formatTime(timerViewModel.currentElapsedSeconds))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color("AppText"))
                .frame(minWidth: 60, alignment: .leading)
            
            Spacer()
            
            // Control buttons
            if timerViewModel.isRunning {
                Button(action: {
                    timerViewModel.stop()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Pause")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    timerViewModel.start()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(timerViewModel.currentElapsedSeconds > 0 ? "Resume" : "Start")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            if timerViewModel.currentElapsedSeconds > 0 {
                Button(action: {
                    showResetConfirmation = true
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LinearGradient.accentWarm)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(LinearGradient.accentWarm.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("AppSurface"))
                
                if timerViewModel.isRunning {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient.accentLight.opacity(0.4))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    timerViewModel.isRunning ?
                        LinearGradient.accent :
                        LinearGradient(
                            colors: [
                                Color("AppSeparator"),
                                Color("AppSeparator").opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: timerViewModel.isRunning ? 1.5 : 0.5
                )
        )
        .enhancedShadow(radius: 6, y: 2)
        .alert("Reset Timer?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {
                showResetConfirmation = false
            }
            Button("Reset", role: .destructive) {
                timerViewModel.reset()
            }
        } message: {
            Text("Are you sure you want to reset the timer? This will clear all elapsed time and cannot be undone.")
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    TimerView(timerViewModel: TimerViewModel())
        .padding()
}

