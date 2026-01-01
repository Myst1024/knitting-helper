//
//  ProjectListViewModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import Combine

/// View model for managing the project list and current project state
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var showNewProjectView = false
    @Published var shouldAddHighlight = false
    @Published var shouldAddNote = false
    @Published var projectToDelete: Project?
    @Published var showDeleteConfirmation = false
    @Published var projectToRename: Project?
    @Published var showRenameDialog = false
    @Published var newProjectName = ""
    @Published var showTimer = false
    @Published var timerViewModel: TimerViewModel?
    
    init() {
        loadProjects()
    }
    
    // MARK: - Project Management
    
    func loadProjects() {
        projects = Project.loadProjects()
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
        do {
            try Project.saveProjects(projects)
        } catch {
            // Log error but continue - project is already in memory
            print("Failed to save projects: \(error)")
        }
        currentProject = project
    }
    
    func openProject(_ project: Project) {
        // Stop timer if one is running
        stopTimerIfNeeded()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentProject = project
        }
        
        // Initialize timer for the new project
        initializeTimer(for: project)
    }
    
    func closeProject() {
        // Stop timer when leaving project view
        stopTimerIfNeeded()
        
        if let current = currentProject {
            // Save counters and timer before closing
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                do {
                    try Project.saveProjects(projects)
                } catch {
                    // Log error but continue - project is already in memory
                    print("Failed to save projects: \(error)")
                }
            }
        }
        
        // Clear timer
        timerViewModel = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentProject = nil
            showTimer = false
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        project.delete()
        if currentProject?.id == project.id {
            currentProject = nil
        }
    }
    
    func renameProject(_ project: Project, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].name = trimmedName
            do {
                try Project.saveProjects(projects)
            } catch {
                // Log error but continue - project is already in memory
                print("Failed to save projects: \(error)")
            }
            
            if currentProject?.id == project.id {
                currentProject?.name = trimmedName
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func prepareRename(_ project: Project) {
        projectToRename = project
        newProjectName = project.name
        showRenameDialog = true
    }
    
    func prepareDelete(_ project: Project) {
        projectToDelete = project
        showDeleteConfirmation = true
    }
    
    func clearRenameState() {
        projectToRename = nil
        newProjectName = ""
    }
    
    func clearDeleteState() {
        projectToDelete = nil
    }
    
    // MARK: - Current Project Updates
    
    func updateCurrentProjectHighlights(_ highlights: [CodableHighlight]) {
        guard var current = currentProject else { return }
        current.highlights = highlights
        currentProject = current
        // Also update in projects array
        if let index = projects.firstIndex(where: { $0.id == current.id }) {
            projects[index] = current
        }
    }
    
    func updateCurrentProjectCounters(_ counters: [Counter]) {
        guard var current = currentProject else { return }
        current.counters = counters
        currentProject = current
        // Also update in projects array
        if let index = projects.firstIndex(where: { $0.id == current.id }) {
            projects[index] = current
        }
    }
    
    func updateCurrentProjectScrollOffset(_ offset: Double) {
        guard var current = currentProject else { return }
        current.scrollOffsetY = offset
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
            }
        }
    }
    
    func updateCurrentProjectNotes(_ notes: [CodableNote]) {
        guard var current = currentProject else { return }
        current.notes = notes
        currentProject = current
        // Also update in projects array
        if let index = projects.firstIndex(where: { $0.id == current.id }) {
            projects[index] = current
        }
    }
    
    func addCounterToCurrentProject() {
        guard var current = currentProject else { return }
        current.counters.append(Counter(name: "Counter \(current.counters.count + 1)"))
        currentProject = current
        // Also update in projects array
        if let index = projects.firstIndex(where: { $0.id == current.id }) {
            projects[index] = current
        }
    }
    
    // MARK: - Timer Management
    
    func toggleTimer() {
        showTimer.toggle()
    }
    
    func initializeTimer(for project: Project) {
        let viewModel = TimerViewModel(
            elapsedSeconds: project.timerElapsedSeconds,
            isRunning: project.timerIsRunning,
            lastStartTime: project.timerLastStartTime
        )
        
        viewModel.setSaveCallback { [weak self] in
            self?.saveTimerState()
        }
        
        timerViewModel = viewModel
    }
    
    private func stopTimerIfNeeded() {
        timerViewModel?.stop()
        saveTimerState()
    }
    
    private func saveTimerState() {
        guard let timerVM = timerViewModel,
              var current = currentProject else { return }
        
        let state = timerVM.timerState
        current.timerElapsedSeconds = state.elapsedSeconds
        current.timerIsRunning = state.isRunning
        current.timerLastStartTime = state.lastStartTime
        
        currentProject = current
        
        // Also update in projects array
        if let index = projects.firstIndex(where: { $0.id == current.id }) {
            projects[index] = current
        }
        
        // Save to disk
        do {
            try Project.saveProjects(projects)
        } catch {
            print("Failed to save timer state: \(error)")
        }
    }
}

