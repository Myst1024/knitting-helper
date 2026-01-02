//
//  ProjectListView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

// MARK: - Constants

private enum Constants {
    static let cornerRadius: CGFloat = 12
}

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

// MARK: - Supporting Views

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

    private func formatTimerTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func formatLastWorkedOnDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if daysAgo < 7 {
                return "\(daysAgo) day\(daysAgo == 1 ? "" : "s") ago"
            } else if daysAgo < 30 {
                let weeksAgo = daysAgo / 7
                return "\(weeksAgo) week\(weeksAgo == 1 ? "" : "s") ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }
    }

    private func buildProjectInfoItems(for project: Project) -> [String] {
        var items: [String] = []

        // Include counters only if there are any
        if project.counters.count > 0 {
            items.append("\(project.counters.count) counter\(project.counters.count == 1 ? "" : "s")")
        }

        // Add notes if any
        if project.notes.count > 0 {
            items.append("\(project.notes.count) note\(project.notes.count == 1 ? "" : "s")")
        }

        // Add timer if any time has been spent
        if project.timerElapsedSeconds > 0 {
            items.append(formatTimerTime(project.timerElapsedSeconds))
        }

        return items
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 16) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(cardGradient)
                            .frame(width: 56, height: 53)
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

                        BulletedList(items: buildProjectInfoItems(for: project))

                        if let lastWorkedOn = formatLastWorkedOnDate(project.lastWorkedOnDate) {
                            Text(lastWorkedOn)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

// MARK: - BulletedList

struct BulletedList: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 6) {
                    if index > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1) // Prevent individual item wrapping
                }
                .fixedSize() // Prevent this item from being compressed
            }
        }
    }
}

// Simple flow layout that keeps items together
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            if currentRowWidth + size.width > containerWidth && currentRowWidth > 0 {
                // Start new row
                height += currentRowHeight + spacing
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                // Add to current row
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        height += currentRowHeight
        return CGSize(width: containerWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(proposal)

            if x + size.width > bounds.maxX && x > bounds.minX {
                // Start new row
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = size.height
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: proposal)
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// MARK: - Project List Header

struct ProjectListHeader: View {
    let isEmpty: Bool
    
    var body: some View {
        ZStack {

            

            

            
            Image("transparent yarnball")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
        }
     
    }
}

