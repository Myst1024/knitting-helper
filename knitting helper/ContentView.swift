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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let project = viewModel.currentProject {
                    ZStack {
                        // PDF Viewer
                        PDFViewer(
                            url: project.pdfURL,
                            shouldAddHighlight: $viewModel.shouldAddHighlight,
                            highlights: Binding(
                                get: { viewModel.currentProject?.highlights ?? [] },
                                set: { viewModel.updateCurrentProjectHighlights($0) }
                            ),
                            counterCount: project.counters.count,
                            scrollOffsetY: Binding(
                                get: { viewModel.currentProject?.scrollOffsetY ?? 0 },
                                set: { viewModel.updateCurrentProjectScrollOffset($0) }
                            )
                        )
                        .edgesIgnoringSafeArea(.bottom)
                        .onAppear {
                            // Initialize timer when project view appears
                            if viewModel.timerViewModel == nil {
                                viewModel.initializeTimer(for: project)
                            }
                        }
                        
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
                            
                            // Highlight button (bottom left)
                            HStack {
                                Button {
                                    viewModel.shouldAddHighlight = true
                                } label: {
                                    ZStack {
                                        // Outer glow
                                        Circle()
                                            .fill(LinearGradient.accentWarmLight)
                                            .frame(width: 48, height: 48)
                                            .blur(radius: 6)
                                        
                                        // Main circle
                                        Circle()
                                            .fill(LinearGradient.accentWarm)
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
                                        
                                        Image(systemName: "highlighter")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .enhancedShadow(color: Color("AccentWarm"), radius: 12, y: 6)
                                .padding(.leading, 16)
                                Spacer()
                            }
                            .padding(.bottom, UIHelper.safeAreaBottomInset() + 16)
                        }
                        .zIndex(1)
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .dismissKeyboardOnTap()
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentProject?.id)
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
        }
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

struct ProjectCard: View {
    let project: Project
    let colorIndex: Int
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    private var cardGradient: LinearGradient {
        switch colorIndex % 4 {
        case 0:
            return LinearGradient.accentLight
        case 1:
            return LinearGradient.accentSecondaryLight
        case 2:
            return LinearGradient.accentTertiaryLight
        default:
            return LinearGradient.accentWarmLight
        }
    }
    
    private var iconGradient: LinearGradient {
        switch colorIndex % 4 {
        case 0:
            return LinearGradient.accent
        case 1:
            return LinearGradient.accentSecondary
        case 2:
            return LinearGradient.accentTertiary
        default:
            return LinearGradient.accentWarm
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 16) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(cardGradient)
                            .frame(width: 56, height: 56)
                            .blur(radius: 4)
                        
                        // Main circle
                        Circle()
                            .fill(iconGradient)
                            .frame(width: 50, height: 50)
                        
                        // Inner highlight
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .foregroundColor(Color("AppText"))
                        
                        Text("\(project.counters.count) counters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Menu {
                Button(action: onRename) {
                    Label("Rename Project", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Project", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
        }
        .background(
            ZStack {
                // Base surface
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color("AppSurface"))
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(cardGradient)
                    .opacity(0.6)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color("AppSeparator"),
                            Color("AppSeparator").opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .enhancedShadow(radius: 10, y: 4)
    }
}


// MARK: - Preview

#Preview {
    ContentView()
}
