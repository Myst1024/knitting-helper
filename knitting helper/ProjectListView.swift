//
//  ProjectListView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

/// View displaying the list of projects or empty state
struct ProjectListView: View {
    let projects: [Project]
    let onOpenProject: (Project) -> Void
    let onRenameProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    let onCreateProject: () -> Void
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header icon
                    ProjectListHeader(isEmpty: projects.isEmpty)
                    
                    // Title and description
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
                    
                    // Project list
                    if !projects.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(projects) { project in
                                ProjectCard(
                                    project: project,
                                    onOpen: { onOpenProject(project) },
                                    onRename: { onRenameProject(project) },
                                    onDelete: { onDeleteProject(project) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Spacing for floating button
                    Color.clear
                        .frame(height: 100)
                }
            }
            
            // Floating create button
            VStack {
                Spacer()
                
                Button {
                    onCreateProject()
                } label: {
                    Label("Start New Project", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.accent())
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Project List Header

struct ProjectListHeader: View {
    let isEmpty: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .accentGradientFill()
                .frame(width: 100, height: 100)
            
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .accentGradient()
        }
        .padding(.top, 40)
    }
}

