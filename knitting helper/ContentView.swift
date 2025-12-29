//
//  ContentView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

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
                    ZStack(alignment: .top) {
                        // PDF Viewer
                        PDFViewer(
                            url: project.pdfURL,
                            shouldAddHighlight: $shouldAddHighlight,
                            highlights: Binding(
                                get: { currentProject?.highlights ?? [] },
                                set: { currentProject?.highlights = $0 }
                            )
                        )
                        
                        // Counters overlay (fixed at top)
                        CountersOverlay(
                            counters: Binding(
                                get: { currentProject?.counters ?? [] },
                                set: { currentProject?.counters = $0 }
                            ),
                            onAddCounter: {
                                currentProject?.counters.append(Counter(name: "Counter \(project.counters.count + 1)"))
                            }
                        )
                        .zIndex(1)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            // Dismiss keyboard when tapping anywhere
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    )
                    
                    // Fixed toolbar at the bottom
                    HStack(spacing: 16) {
                        Button {
                            shouldAddHighlight = true
                        } label: {
                            Image(systemName: "highlighter")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: -2)
                } else {
                    // Empty state - show projects list or welcome screen
                    ScrollView {
                        VStack(spacing: 24) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 60))
                                .foregroundStyle(.purple)
                                .padding(.top, 40)
                            
                            VStack(spacing: 8) {
                                Text(projects.isEmpty ? "Welcome to Knitting Helper" : "Your Projects")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
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
                                        HStack(spacing: 0) {
                                            Button {
                                                openProject(project)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "folder.fill")
                                                        .font(.title2)
                                                        .foregroundColor(.purple)
                                                    
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
                                                Button {
                                                    projectToRename = project
                                                    newProjectName = project.name
                                                    showRenameDialog = true
                                                } label: {
                                                    Label("Rename Project", systemImage: "pencil")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    projectToDelete = project
                                                    showDeleteConfirmation = true
                                                } label: {
                                                    Label("Delete Project", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle")
                                                    .font(.title3)
                                                    .foregroundColor(.secondary)
                                                    .padding(.trailing, 16)
                                            }
                                        }
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.systemGray6))
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Create new project button
                            Button {
                                showNewProjectView = true
                            } label: {
                                Label("Create New Project", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.purple)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 40)
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
            
            // Update current project if it's the one being renamed
            if currentProject?.id == project.id {
                currentProject?.name = trimmedName
            }
        }
    }
}

#Preview {
    ContentView()
}
