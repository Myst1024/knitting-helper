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

    // Bookmark creation handler
    
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
                highlights: Binding(
                    get: { viewModel.currentProject?.highlights ?? [] },
                    set: { viewModel.updateCurrentProjectHighlights($0) }
                ),
                notes: Binding(
                    get: { viewModel.currentProject?.notes ?? [] },
                    set: { viewModel.updateCurrentProjectNotes($0) }
                ),
                bookmarks: Binding(
                    get: { viewModel.bookmarks },
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
                // Highlight button
                Button {
                    viewModel.shouldAddHighlight = true
                } label: {
                    ZStack {
                        // Main circle
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)
                        
                        // Inner highlight
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
                
                // Note button
                Button {
                    viewModel.shouldAddNote = true
                } label: {
                    ZStack {
                        // Main circle
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)

                        // Inner highlight
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
                
                // Bookmark button
                Button {
                    viewModel.showBookmarkList = true
                } label: {
                    ZStack {

                        // Main circle
                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 44, height: 44)

                        // Inner highlight
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
                    bookmarks: viewModel.bookmarks,
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
        .alert("Delete Project?", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.projectToDelete) { project in
            Button("Cancel", role: .cancel) {
                viewModel.clearDeleteState()
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteProject(project)
                viewModel.clearDeleteState()
            }
        } message: { project in
            Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
        }
        .alert("Rename Project", isPresented: $viewModel.showRenameDialog, presenting: viewModel.projectToRename) { project in
            TextField("Project Name", text: $viewModel.newProjectName)
            Button("Cancel", role: .cancel) {
                viewModel.clearRenameState()
            }
            Button("Rename") {
                viewModel.renameProject(project, to: viewModel.newProjectName)
                viewModel.clearRenameState()
            }
            .disabled(viewModel.newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: { project in
            Text("Enter a new name for \"\(project.name)\"")
        }
        .alert("Create Bookmark", isPresented: $viewModel.showBookmarkDialog) {
            TextField("Bookmark Name", text: $viewModel.bookmarkName)
            Button("Cancel", role: .cancel) {
                viewModel.bookmarkName = ""
                viewModel.showBookmarkDialog = false
            }
            Button("Create") {
                bookmarkNameToCreate = viewModel.bookmarkName
                viewModel.bookmarkName = ""
                viewModel.showBookmarkDialog = false
            }
            .disabled(viewModel.bookmarkName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a name for the bookmark")
        }
        .alert("Delete Bookmark", isPresented: $viewModel.showDeleteBookmarkConfirmation, presenting: viewModel.bookmarkToDelete) { bookmark in
            Button("Cancel", role: .cancel) {
                viewModel.clearBookmarkManagementState()
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteBookmark(bookmark)
                viewModel.clearBookmarkManagementState()
            }
        } message: { bookmark in
            Text("Are you sure you want to delete the bookmark \"\(bookmark.name)\"? This action cannot be undone.")
        }
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
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
    }
}
