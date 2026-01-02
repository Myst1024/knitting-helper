//
//  ContentView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

// MARK: - Constants

private enum Constants {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let iconSize: CGFloat = 60
    static let toolbarButtonSize: CGFloat = 44
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = ProjectListViewModel()

    // Bookmark creation trigger (holds the name when creating)
    @State private var bookmarkNameToCreate: String? = nil

    // MARK: - PDF Viewer Section
    private var pdfViewerSection: some View {
        guard let currentProject = viewModel.currentProject else {
            // This should never happen since pdfViewerSection is only displayed when currentProject != nil,
            // but we guard against it for safety during animation transitions
            return AnyView(EmptyView())
        }

        return AnyView(
            PDFViewer(
                url: currentProject.pdfURL,
                shouldAddHighlight: $viewModel.shouldAddHighlight,
                shouldAddNote: $viewModel.shouldAddNote,
                bookmarkName: $viewModel.bookmarkName,
                onCreateBookmark: { name, page, xFraction, yFraction in
                    viewModel.createBookmark(name: name, page: page, xFraction: xFraction, yFraction: yFraction)
                },
                onDeleteNote: { noteID in
                    viewModel.requestDeleteNote(noteID)
                },
                noteToDeleteFromUI: $viewModel.noteToDeleteFromUI,
                highlights: Binding(
                    get: { viewModel.currentProject?.highlights ?? [] },
                    set: { viewModel.updateCurrentProjectHighlights($0) }
                ),
                notes: Binding(
                    get: { viewModel.currentProject?.notes ?? [] },
                    set: { viewModel.updateCurrentProjectNotes($0) }
                ),
                bookmarks: Binding(
                    get: { viewModel.currentProject?.bookmarks ?? [] },
                    set: { viewModel.updateCurrentProjectBookmarks($0) }
                ),
                counterCount: currentProject.counters.count,
                scrollOffsetY: Binding(
                    get: { viewModel.currentProject?.scrollOffsetY ?? 0 },
                    set: { viewModel.updateCurrentProjectScrollOffset($0) }
                ),
                selectedBookmark: $viewModel.selectedBookmark,
                bookmarkToRecolor: $viewModel.bookmarkToRecolor,
                shouldShowBookmarkColorPicker: $viewModel.shouldShowBookmarkColorPicker,
                bookmarkNameToCreate: $bookmarkNameToCreate
            )
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                // Initialize timer when project view appears
                if viewModel.timerViewModel == nil {
                    viewModel.initializeTimer(for: currentProject)
                }
            }
        )
    }
    
    // MARK: - Overlays Section
    private var overlaysSection: some View {
        VStack {
            // Timer overlay (if visible) - above counters
            if viewModel.showTimer, let timerVM = viewModel.timerViewModel {
                TimerView(timerViewModel: timerVM)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Counters overlay (fixed at top)
            CountersOverlay(
                counters: Binding(
                    get: { viewModel.currentProject?.counters ?? [] },
                    set: { viewModel.updateCurrentProjectCounters($0) }
                ),
                onAddCounter: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewModel.addCounterToCurrentProject()
                    }
                }
            )
            
            Spacer()
            
            // Toolbar (fixed at bottom)
            HStack(spacing: 16) {
                Button {
                    viewModel.shouldAddHighlight = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "pencil.tip.crop.circle.badge.plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .enhancedShadow(color: Color("AccentColor"), radius: 12, y: 6)

                Button {
                    viewModel.shouldAddNote = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .enhancedShadow(color: Color("AccentColor"), radius: 12, y: 6)

                Button {
                    viewModel.showBookmarkList = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .enhancedShadow(color: Color("AccentColor"), radius: 12, y: 6)
                
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.bottom, UIHelper.safeAreaBottomInset() + 16)
        }
        .zIndex(1)
    }
    
    // MARK: - Overlays Section (Bookmark List)
    private var bookmarkListOverlay: some View {
        Group {
            if viewModel.showBookmarkList {
                BookmarkListView(
                    isPresented: $viewModel.showBookmarkList,
                    bookmarks: viewModel.currentProject?.bookmarks ?? [],
                    onSelectBookmark: { bookmark in
                        viewModel.navigateToBookmark(bookmark)
                    },
                    onCreateNewBookmark: {
                        viewModel.showBookmarkDialog = true
                    },
                    onRecolorBookmark: { bookmark in
                        viewModel.prepareRecolorBookmark(bookmark)
                    },
                    onDeleteBookmark: { bookmark in
                        viewModel.prepareDeleteBookmark(bookmark)
                    }
                )
                .zIndex(2)
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            if viewModel.currentProject != nil {
                ZStack {
                    pdfViewerSection
                    overlaysSection
                    bookmarkListOverlay
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .dismissKeyboardOnTap()
                .onAppear {
                    // Disable idle timer when viewing a project to keep screen on
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    // Re-enable idle timer when leaving project view
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                ZStack {
                    // Subtle background gradient
                    LinearGradient.backgroundSubtle
                        .ignoresSafeArea()

                    ProjectListView(
                        projects: viewModel.projects,
                        onOpenProject: { viewModel.openProject($0) },
                        onRenameProject: { viewModel.prepareRename($0) },
                        onDeleteProject: { viewModel.prepareDelete($0) },
                        onCreateProject: { viewModel.showNewProjectView = true }
                    )
                }
                .onAppear {
                    // Enable idle timer on home screen to allow normal screen sleep
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .navigationTitle(viewModel.currentProject?.name ?? "Knitting Helper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.currentProject != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.closeProject()
                    } label: {
                        Image(systemName: "house.fill")
                            .foregroundStyle(LinearGradient.accent)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    TimerToolbarButton(
                        showTimer: viewModel.showTimer,
                        timerViewModel: viewModel.timerViewModel,
                        onToggle: { viewModel.toggleTimer() }
                    )
                }
            }
        }
        .projectAlerts(
            showDeleteConfirmation: $viewModel.showDeleteConfirmation,
            projectToDelete: viewModel.projectToDelete,
            clearDeleteState: { viewModel.clearDeleteState() },
            deleteProject: { viewModel.deleteProject($0) },
            showRenameDialog: $viewModel.showRenameDialog,
            projectToRename: viewModel.projectToRename,
            newProjectName: $viewModel.newProjectName,
            clearRenameState: { viewModel.clearRenameState() },
            renameProject: { viewModel.renameProject($0, to: $1) }
        )
        .bookmarkAlerts(
            showBookmarkDialog: $viewModel.showBookmarkDialog,
            bookmarkName: $viewModel.bookmarkName,
            bookmarkNameToCreate: $bookmarkNameToCreate,
            showDeleteBookmarkConfirmation: $viewModel.showDeleteBookmarkConfirmation,
            bookmarkToDelete: viewModel.bookmarkToDelete,
            clearBookmarkManagementState: { viewModel.clearBookmarkManagementState() },
            deleteBookmark: { viewModel.deleteBookmark($0) }
        )
        .noteAlerts(
            showDeleteNoteConfirmation: $viewModel.showDeleteNoteConfirmation,
            noteToDelete: viewModel.noteToDelete,
            clearDeleteNoteState: { viewModel.clearDeleteNoteState() },
            deleteNote: { viewModel.deleteNote($0) }
        )
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            mainContent
        }
        .sheet(isPresented: $viewModel.showNewProjectView) {
            NewProjectView(project: Binding(
                get: { nil },
                set: { newProject in
                    if let newProject = newProject {
                        viewModel.addProject(newProject)
                    }
                }
            ))
        }
    }
    
    // MARK: - Supporting Views
    
    struct TimerToolbarButton: View {
        let showTimer: Bool
        let timerViewModel: TimerViewModel?
        let onToggle: () -> Void
        
        private var iconName: String {
            if let timerVM = timerViewModel, timerVM.isRunning {
                return "stopwatch.fill"
            } else if showTimer {
                return "stopwatch.fill"
            } else {
                return "stopwatch"
            }
        }
        
        private var isRunning: Bool {
            timerViewModel?.isRunning ?? false
        }
        
        var body: some View {
            Button(action: onToggle) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .foregroundStyle(
                            isRunning ?
                            LinearGradient.accent :
                                LinearGradient(
                                    colors: [
                                        Color("AccentColor").opacity(0.6),
                                        Color("AccentColor").opacity(0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                    
                    // Static indicator dot when running
                    if isRunning {
                        Circle()
                            .fill(Color("AccentColor"))
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
    }
}

// MARK: - Alert Containers
private extension View {
    func projectAlerts(
        showDeleteConfirmation: Binding<Bool>,
        projectToDelete: Project?,
        clearDeleteState: @escaping () -> Void,
        deleteProject: @escaping (Project) -> Void,
        showRenameDialog: Binding<Bool>,
        projectToRename: Project?,
        newProjectName: Binding<String>,
        clearRenameState: @escaping () -> Void,
        renameProject: @escaping (Project, String) -> Void
    ) -> some View {
        self
            .alert("Delete Project?", isPresented: showDeleteConfirmation, presenting: projectToDelete) { project in
                Button("Cancel", role: .cancel) {
                    clearDeleteState()
                }
                Button("Delete", role: .destructive) {
                    deleteProject(project)
                    clearDeleteState()
                }
            } message: { project in
                Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
            }
            .alert("Rename Project", isPresented: showRenameDialog, presenting: projectToRename) { project in
                TextField("Project Name", text: newProjectName)
                Button("Cancel", role: .cancel) {
                    clearRenameState()
                }
                Button("Rename") {
                    renameProject(project, newProjectName.wrappedValue)
                    clearRenameState()
                }
                .disabled(newProjectName.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: { project in
                Text("Enter a new name for \"\(project.name)\"")
            }
    }

    func bookmarkAlerts(
        showBookmarkDialog: Binding<Bool>,
        bookmarkName: Binding<String>,
        bookmarkNameToCreate: Binding<String?>,
        showDeleteBookmarkConfirmation: Binding<Bool>,
        bookmarkToDelete: CodableBookmark?,
        clearBookmarkManagementState: @escaping () -> Void,
        deleteBookmark: @escaping (CodableBookmark) -> Void
    ) -> some View {
        self
            .alert("Create Bookmark", isPresented: showBookmarkDialog) {
                TextField("Bookmark Name", text: bookmarkName)
                Button("Cancel", role: .cancel) {
                    bookmarkName.wrappedValue = ""
                    showBookmarkDialog.wrappedValue = false
                }
                Button("Create") {
                    bookmarkNameToCreate.wrappedValue = bookmarkName.wrappedValue
                    bookmarkName.wrappedValue = ""
                    showBookmarkDialog.wrappedValue = false
                }
                .disabled(bookmarkName.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for the bookmark")
            }
            .alert("Delete Bookmark", isPresented: showDeleteBookmarkConfirmation, presenting: bookmarkToDelete) { bookmark in
                Button("Cancel", role: .cancel) {
                    clearBookmarkManagementState()
                }
                Button("Delete", role: .destructive) {
                    deleteBookmark(bookmark)
                    clearBookmarkManagementState()
                }
            } message: { bookmark in
                Text("Are you sure you want to delete the bookmark \"\(bookmark.name)\"? This action cannot be undone.")
            }
    }

    func noteAlerts(
        showDeleteNoteConfirmation: Binding<Bool>,
        noteToDelete: UUID?,
        clearDeleteNoteState: @escaping () -> Void,
        deleteNote: @escaping (UUID) -> Void
    ) -> some View {
        self
            .alert("Delete Note?", isPresented: showDeleteNoteConfirmation, presenting: noteToDelete) { noteID in
                Button("Cancel", role: .cancel) {
                    clearDeleteNoteState()
                }
                Button("Delete", role: .destructive) {
                    deleteNote(noteID)
                    clearDeleteNoteState()
                }
            } message: { noteID in
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
    }
}
