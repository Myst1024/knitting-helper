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
    @Published var bookmarks: [CodableBookmark] = []
    @Published var showNewProjectView = false

    private func syncBookmarksWithCurrentProject() {
        bookmarks = currentProject?.bookmarks ?? []
    }
    @Published var shouldAddHighlight = false
    @Published var shouldAddNote = false
    @Published var showBookmarkDialog = false
    @Published var showBookmarkList = false
    @Published var bookmarkName = ""
    @Published var selectedBookmark: CodableBookmark?
    @Published var bookmarkToRecolor: CodableBookmark?
    @Published var shouldShowBookmarkColorPicker = false
    @Published var bookmarkToDelete: CodableBookmark?
    @Published var showDeleteBookmarkConfirmation = false
    @Published var shouldAddBookmark = false
    @Published var projectToDelete: Project?
    @Published var showDeleteConfirmation = false
    @Published var projectToRename: Project?
    @Published var showRenameDialog = false
    @Published var newProjectName = ""
    @Published var showTimer = false
    @Published var timerViewModel: TimerViewModel?
    private var navigationState: NavigationState = .idle

    private enum NavigationState {
        case idle
        case closing
    }
    
    init() {
        loadProjects()
    }
    
    // MARK: - Project Management
    
    func loadProjects() {
        projects = Project.loadProjects()
        sortProjects()
    }

    private func sortProjects() {
        projects.sort { lhs, rhs in
            // Sort by lastWorkedOnDate descending (most recent first)
            // Projects with no date come last
            switch (lhs.lastWorkedOnDate, rhs.lastWorkedOnDate) {
            case (let lhsDate?, let rhsDate?):
                return lhsDate > rhsDate
            case ( _?, nil):
                return true // lhs with date comes before rhs without date
            case (nil, _?):
                return false // rhs with date comes before lhs without date
            case (nil, nil):
                return false // both without date, maintain original order
            }
        }
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
        sortProjects() // Sort so newly created projects appear at top
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
        
        // Update last worked on date
        var updatedProject = project
        updatedProject.lastWorkedOnDate = Date()
        
        // Update in projects array
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
            projects[index] = updatedProject
            sortProjects() // Sort so recently opened project appears at top
            do {
                try Project.saveProjects(projects)
            } catch {
                print("Failed to save last worked on date: \(error)")
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentProject = updatedProject
            bookmarks = updatedProject.bookmarks
        }
        
        // Initialize timer for the new project
        initializeTimer(for: updatedProject)
    }
    
    func closeProject() {
        // Stop timer when leaving project view
        stopTimerIfNeeded()

        // Set navigation state to prevent updates during closing
        navigationState = .closing

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
        } completion: {
            // Clear navigation state after animation completes
            self.navigationState = .idle
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
        guard var current = currentProject, navigationState == .idle else { return }
        current.highlights = highlights
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save project: \(error)")
                }
            }
        }
    }
    
    func updateCurrentProjectCounters(_ counters: [Counter]) {
        guard var current = currentProject, navigationState == .idle else { return }
        current.counters = counters
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save project: \(error)")
                }
            }
        }
    }
    
    func updateCurrentProjectScrollOffset(_ offset: Double) {
        guard var current = currentProject, navigationState == .idle else { return }
        current.scrollOffsetY = offset
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
            }
        }
    }
    
    func updateCurrentProjectNotes(_ notes: [CodableNote]) {
        guard var current = currentProject, navigationState == .idle else { return }
        current.notes = notes
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save project: \(error)")
                }
            }
        }
    }

    func updateCurrentProjectBookmarks(_ bookmarks: [CodableBookmark]) {
        guard var current = currentProject, navigationState == .idle else { return }
        current.bookmarks = bookmarks
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            self.bookmarks = bookmarks // Update the @Published property
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save project: \(error)")
                }
            }
        }
    }
    
    func addCounterToCurrentProject() {
        guard var current = currentProject, navigationState == .idle else { return }
        current.counters.append(Counter(name: "Counter \(current.counters.count + 1)"))
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current
            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save project: \(error)")
                }
            }
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
              var current = currentProject,
              navigationState == .idle else { return }

        let state = timerVM.timerState
        current.timerElapsedSeconds = state.elapsedSeconds
        current.timerIsRunning = state.isRunning
        current.timerLastStartTime = state.lastStartTime
        // Update last worked on date when timer is running
        if state.isRunning {
            current.lastWorkedOnDate = Date()
        }

        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current

            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                if state.isRunning {
                    sortProjects() // Sort so recently updated project appears at top
                }
            }

            // Save to disk
            do {
                try Project.saveProjects(projects)
            } catch {
                print("Failed to save timer state: \(error)")
            }
        }
    }

    // MARK: - Bookmark Navigation

    func navigateToBookmark(_ bookmark: CodableBookmark) {
        selectedBookmark = bookmark
        // The PDFViewer will observe this change and navigate to the bookmark
    }

    // MARK: - Bookmark Management

    func prepareRecolorBookmark(_ bookmark: CodableBookmark) {
        bookmarkToRecolor = bookmark
        shouldShowBookmarkColorPicker = true
    }

    func prepareDeleteBookmark(_ bookmark: CodableBookmark) {
        bookmarkToDelete = bookmark
        showDeleteBookmarkConfirmation = true
    }

    func recolorBookmark(_ bookmark: CodableBookmark, to newColorHex: String) {
        guard let index = projects.firstIndex(where: { $0.id == currentProject?.id }),
              let bookmarkIndex = projects[index].bookmarks.firstIndex(where: { $0.id == bookmark.id }),
              navigationState == .idle else {
            return
        }

        projects[index].bookmarks[bookmarkIndex].colorHex = newColorHex
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = projects[index]

            // Save changes
            do {
                try Project.saveProjects(projects)
            } catch {
                print("Failed to save bookmark recolor: \(error)")
            }
        }
    }

    func deleteBookmark(_ bookmark: CodableBookmark) {
        guard let index = projects.firstIndex(where: { $0.id == currentProject?.id }),
              navigationState == .idle else {
            return
        }

        projects[index].bookmarks.removeAll { $0.id == bookmark.id }
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = projects[index]

            // Update the @Published bookmarks property to trigger UI updates
            bookmarks = currentProject?.bookmarks ?? []

            // Save changes
            do {
                try Project.saveProjects(projects)
            } catch {
                print("Failed to save bookmark deletion: \(error)")
            }
        }
    }

    func createBookmark(name: String, page: Int, xFraction: CGFloat, yFraction: CGFloat) {
        guard var current = currentProject, navigationState == .idle else { return }

        // Create bookmark at the specified position
        let bookmark = CodableBookmark(
            id: UUID(),
            page: page,
            xFraction: xFraction,
            yFraction: yFraction,
            name: name,
            colorHex: UIColor.systemGreen.toHex()
        )

        current.bookmarks.append(bookmark)
        current.lastWorkedOnDate = Date()
        // Defer updates to avoid publishing during view updates
        Task { @MainActor in
            guard self.navigationState == .idle else { return }
            currentProject = current

            // Update the @Published bookmarks property to trigger UI updates
            bookmarks = current.bookmarks

            // Also update in projects array
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                sortProjects() // Sort so recently updated project appears at top
                // Save to disk
                do {
                    try Project.saveProjects(projects)
                } catch {
                    print("Failed to save bookmark creation: \(error)")
                }
            }
        }
    }

    func clearBookmarkManagementState() {
        bookmarkToRecolor = nil
        shouldShowBookmarkColorPicker = false
        bookmarkToDelete = nil
        showDeleteBookmarkConfirmation = false
    }

}

