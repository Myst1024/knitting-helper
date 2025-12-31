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
                        
                        VStack {
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
                                    Image(systemName: "highlighter")
                                        .font(.title2)
                                        .accentGradient()
                                        .background(
                                            Circle()
                                                .fill(Color("AppSurface"))
                                                .frame(width: 36, height: 36)
                                        )
                                        .shadow(color: Color("AppText").opacity(0.15), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
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
                    ProjectListView(
                        projects: viewModel.projects,
                        onOpenProject: { viewModel.openProject($0) },
                        onRenameProject: { viewModel.prepareRename($0) },
                        onDeleteProject: { viewModel.prepareDelete($0) },
                        onCreateProject: { viewModel.showNewProjectView = true }
                    )
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
                        }
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

struct ProjectCard: View {
    let project: Project
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .accentGradientFill()
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .accentGradient()
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
                                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                        .fill(Color("AppSurface"))
                                        .shadow(color: Color("AppText").opacity(0.06), radius: 8, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                        .stroke(Color("AppSeparator"), lineWidth: 0.5)
                                )
    }
}


// MARK: - Preview

#Preview {
    ContentView()
}
