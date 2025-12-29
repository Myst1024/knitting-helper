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
    @State private var projects: [Project] = []
    @State private var currentProject: Project?
    @State private var showNewProjectView = false
    @State private var shouldAddHighlight = false
    @State private var projectToDelete: Project?
    @State private var showDeleteConfirmation = false
    @State private var projectToRename: Project?
    @State private var showRenameDialog = false
    @State private var newProjectName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let project = currentProject {
                    ZStack {
                        // PDF Viewer
                        PDFViewer(
                            url: project.pdfURL,
                            shouldAddHighlight: $shouldAddHighlight,
                            highlights: Binding(
                                get: { currentProject?.highlights ?? [] },
                                set: { currentProject?.highlights = $0 }
                            ),
                            counterCount: project.counters.count,
                            scrollOffsetY: Binding(
                                get: { currentProject?.scrollOffsetY ?? 0 },
                                set: { currentProject?.scrollOffsetY = $0 }
                            )
                        )
                        
                        VStack {
                            // Counters overlay (fixed at top)
                            CountersOverlay(
                                counters: Binding(
                                    get: { currentProject?.counters ?? [] },
                                    set: { currentProject?.counters = $0 }
                                ),
                                onAddCounter: {
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        currentProject?.counters.append(Counter(name: "Counter \(project.counters.count + 1)"))
                                    }
                                }
                            )
                            
                            Spacer()
                            
                            // Highlight button (bottom left)
                            HStack {
                                Button {
                                    shouldAddHighlight = true
                                } label: {
                                    Image(systemName: "highlighter")
                                        .font(.title2)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .background(
                                            Circle()
                                                .fill(Color(.systemBackground))
                                                .frame(width: 36, height: 36)
                                        )
                                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 16)
                                .padding(.bottom, 16)
                                
                                Spacer()
                            }
                        }
                        .zIndex(1)
                    }
                    .dismissKeyboardOnTap()
                } else {
                    // Empty state - show projects list or welcome screen
                    ZStack {
                        ScrollView {
                            VStack(spacing: 24) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.cyan.opacity(0.2), Color.cyan.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: Constants.iconSize))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .padding(.top, 40)
                                
                                VStack(spacing: 8) {
                                    Text(projects.isEmpty ? "Welcome to Knitting Helper" : "Your Projects")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    if projects.isEmpty {
                                        Text("Create a project to get started")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Show existing projects
                                if !projects.isEmpty {
                                    VStack(spacing: 12) {
                                        ForEach(projects) { project in
                                            ProjectCard(
                                                project: project,
                                                onOpen: { openProject(project) },
                                                onRename: {
                                                    projectToRename = project
                                                    newProjectName = project.name
                                                    showRenameDialog = true
                                                },
                                                onDelete: {
                                                    projectToDelete = project
                                                    showDeleteConfirmation = true
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Add spacing for the floating button at the bottom
                                Color.clear
                                    .frame(height: 100)
                            }
                        }
                        
                        // Floating Start New Project button
                        VStack {
                            Spacer()
                            
                            Button {
                                showNewProjectView = true
                            } label: {
                                Label("Start New Project", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.cyan.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(currentProject?.name ?? "Knitting Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentProject != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            closeProject()
                        } label: {
                            Image(systemName: "house.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewProjectView) {
                NewProjectView(project: Binding(
                    get: { nil },
                    set: { newProject in
                        if let newProject = newProject {
                            addProject(newProject)
                        }
                    }
                ))
            }
            .alert("Delete Project?", isPresented: $showDeleteConfirmation, presenting: projectToDelete) { project in
                Button("Cancel", role: .cancel) {
                    projectToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteProject(project)
                    projectToDelete = nil
                }
            } message: { project in
                Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
            }
            .alert("Rename Project", isPresented: $showRenameDialog, presenting: projectToRename) { project in
                TextField("Project Name", text: $newProjectName)
                Button("Cancel", role: .cancel) {
                    projectToRename = nil
                    newProjectName = ""
                }
                Button("Rename") {
                    renameProject(project, to: newProjectName)
                    projectToRename = nil
                    newProjectName = ""
                }
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: { project in
                Text("Enter a new name for \"\(project.name)\"")
            }
            .onAppear {
                loadProjects()
            }
        }
    }
    
    // MARK: - Project Management
    
    private func loadProjects() {
        projects = Project.loadProjects()
    }
    
    private func addProject(_ project: Project) {
        projects.append(project)
        Project.saveProjects(projects)
        currentProject = project
    }
    
    private func openProject(_ project: Project) {
        currentProject = project
    }
    
    private func closeProject() {
        if let current = currentProject {
            // Save counters before closing
            if let index = projects.firstIndex(where: { $0.id == current.id }) {
                projects[index] = current
                Project.saveProjects(projects)
            }
        }
        currentProject = nil
    }
    
    private func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        project.delete()
        if currentProject?.id == project.id {
            currentProject = nil
        }
    }
    
    private func renameProject(_ project: Project, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].name = trimmedName
            Project.saveProjects(projects)
            
            if currentProject?.id == project.id {
                currentProject?.name = trimmedName
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
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.2), Color.cyan.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

// MARK: - View Extensions

extension View {
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
