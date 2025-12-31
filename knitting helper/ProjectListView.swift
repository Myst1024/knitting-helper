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
            // Subtle background gradient
            LinearGradient.backgroundSubtle
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header icon
                    ProjectListHeader(isEmpty: projects.isEmpty)
                    
                    // Title and description
                    VStack(spacing: 8) {
                        Text(projects.isEmpty ? "Welcome to Knitting Helper" : "Your Projects")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("AppText"))
                        
                        if projects.isEmpty {
                            Text("Create a project to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Project list
                    if !projects.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                                ProjectCard(
                                    project: project,
                                    colorIndex: index,
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
                .enhancedShadow(color: Color("AccentColor"), radius: 12, y: 6)
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
            // Outer glow effect
            Circle()
                .fill(LinearGradient.rainbowSubtle)
                .frame(width: 110, height: 110)
                .blur(radius: 8)
            
            // Main circle with gradient
            Circle()
                .fill(LinearGradient.accent)
                .frame(width: 100, height: 100)
            
            // Inner highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: 100, height: 100)
            
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
        .enhancedShadow(color: Color("AccentColor"), radius: 16, y: 8)
        .padding(.top, 40)
    }
}

