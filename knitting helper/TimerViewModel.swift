//
//  TimerViewModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import SwiftUI
import Combine

/// View model for managing timer state with background persistence
@MainActor
class TimerViewModel: ObservableObject {
    @Published var elapsedSeconds: Double = 0
    @Published var isRunning: Bool = false
    
    private var lastStartTime: Date?
    nonisolated(unsafe) private var timer: Timer?
    nonisolated(unsafe) private var saveTimer: Timer?
    private var backgroundTime: Date?
    private var onSave: (() -> Void)?
    private var notificationObservers: [NSObjectProtocol] = []
    
    /// Initialize with existing timer state
    init(elapsedSeconds: Double = 0, isRunning: Bool = false, lastStartTime: Date? = nil) {
        // If timer was running when saved, elapsedSeconds is the total at save time
        // and lastStartTime is when we saved. We need to add time that passed since then.
        if isRunning, let savedTime = lastStartTime {
            let timeSinceSave = Date().timeIntervalSince(savedTime)
            self.elapsedSeconds = elapsedSeconds + timeSinceSave
            self.lastStartTime = Date() // Reset to now for continued tracking
        } else {
            self.elapsedSeconds = elapsedSeconds
            self.lastStartTime = lastStartTime
        }
        
        self.isRunning = isRunning
        
        setupNotifications()
        startTimerIfNeeded()
        startPeriodicSave()
    }
    
    deinit {
        stopTimer()
        stopPeriodicSave()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastStartTime = Date()
        startTimer()
        saveTimerState()
    }
    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        // Add elapsed time since last start
        if let startTime = lastStartTime {
            let timeSinceStart = Date().timeIntervalSince(startTime)
            elapsedSeconds += timeSinceStart
            lastStartTime = nil
        }
        
        stopTimer()
        saveTimerState()
    }
    
    func reset() {
        stop()
        elapsedSeconds = 0
        lastStartTime = nil
        saveTimerState()
    }
    
    func setSaveCallback(_ callback: @escaping () -> Void) {
        onSave = callback
    }
    
    // MARK: - Timer Management
    
    private func startTimerIfNeeded() {
        if isRunning {
            startTimer()
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
    }
    
    nonisolated private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        // Trigger a view update by publishing a change
        // The actual time calculation happens in currentElapsedSeconds
        objectWillChange.send()
    }
    
    // MARK: - Background/Foreground Handling
    
    private func setupNotifications() {
        let willResignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppWillResignActive()
            }
        }
        
        let didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppDidBecomeActive()
            }
        }
        
        notificationObservers = [willResignObserver, didBecomeActiveObserver]
    }
    
    private func handleAppWillResignActive() {
        // Save current state when app goes to background
        if isRunning {
            // Update elapsed seconds with time since last start
            if let startTime = lastStartTime {
                let timeSinceStart = Date().timeIntervalSince(startTime)
                elapsedSeconds += timeSinceStart
            }
            // Update lastStartTime to now so we can continue tracking
            lastStartTime = Date()
            backgroundTime = Date()
            saveTimerState()
        }
    }
    
    private func handleAppDidBecomeActive() {
        // Restore elapsed time when app comes to foreground
        if isRunning, let bgTime = backgroundTime {
            // Calculate time that passed while in background
            let backgroundElapsed = Date().timeIntervalSince(bgTime)
            elapsedSeconds += backgroundElapsed
            // Update lastStartTime to now for continued tracking
            lastStartTime = Date()
            backgroundTime = nil
            saveTimerState()
        }
    }
    
    // MARK: - Persistence
    
    private func startPeriodicSave() {
        // Save every 30 seconds to prevent data loss
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveTimerState()
            }
        }
    }
    
    nonisolated private func stopPeriodicSave() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    private func saveTimerState() {
        // Save current state - onSave callback will read timerState
        // which includes the current elapsed time calculation
        onSave?()
    }
    
    // MARK: - Computed Properties
    
    var currentElapsedSeconds: Double {
        if isRunning, let startTime = lastStartTime {
            let timeSinceStart = Date().timeIntervalSince(startTime)
            // elapsedSeconds is the base time accumulated before the current session
            return elapsedSeconds + timeSinceStart
        }
        return elapsedSeconds
    }
    
    var timerState: (elapsedSeconds: Double, isRunning: Bool, lastStartTime: Date?) {
        // When saving while running, we need to save the total elapsed time
        // and update lastStartTime to now so restoration continues correctly
        if isRunning, let startTime = lastStartTime {
            let timeSinceStart = Date().timeIntervalSince(startTime)
            let totalElapsed = elapsedSeconds + timeSinceStart
            // Return total elapsed as the new base, with lastStartTime set to now
            // This way, when restored, elapsedSeconds will be the total, and
            // we'll set lastStartTime to the current time to continue tracking
            return (totalElapsed, isRunning, Date())
        }
        return (elapsedSeconds, isRunning, lastStartTime)
    }
}

