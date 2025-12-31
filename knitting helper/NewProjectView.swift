//
//  NewProjectView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import SwiftUI

// MARK: - Constants

private enum Constants {
    static let iconSize: CGFloat = 60
    static let cornerRadius: CGFloat = 12
    static let cornerRadius8: CGFloat = 8
    static let buttonHeight: CGFloat = 50
}

// MARK: - NewProjectView

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project?
    
    @StateObject private var viewModel = NewProjectViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background gradient
                LinearGradient.backgroundSubtle
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Icon
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
                            .font(.system(size: Constants.iconSize))
                            .foregroundColor(.white)
                    }
                    .enhancedShadow(color: Color("AccentColor"), radius: 16, y: 8)
                    .padding(.top, 40)
                
                Text("Create New Project")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("AppText"))
                
                VStack(spacing: 16) {
                    // Project name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("My Project", text: $viewModel.projectName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // PDF selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pattern PDF")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            viewModel.showDocumentPicker = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    // Outer glow
                                    Circle()
                                        .fill(LinearGradient.accentSecondaryLight)
                                        .frame(width: 50, height: 50)
                                        .blur(radius: 4)
                                    
                                    // Main circle
                                    Circle()
                                        .fill(LinearGradient.accentSecondary)
                                        .frame(width: 44, height: 44)
                                    
                                    // Inner highlight
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.25), Color.clear],
                                                startPoint: .topLeading,
                                                endPoint: .center
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: viewModel.selectedPDFURL == nil ? "doc.badge.plus" : "doc.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    if let url = viewModel.selectedPDFURL {
                                        Text(url.lastPathComponent)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color("AppText"))
                                            .lineLimit(1)
                                        Text("Tap to change")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Select PDF Pattern")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color("AppText"))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                ZStack {
                                    // Base surface
                                    RoundedRectangle(cornerRadius: Constants.cornerRadius8)
                                        .fill(Color("AppSurface"))
                                    
                                    // Subtle gradient overlay
                                    RoundedRectangle(cornerRadius: Constants.cornerRadius8)
                                        .fill(LinearGradient.accentSecondaryLight.opacity(0.5))
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.cornerRadius8)
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
                        .buttonStyle(.plain)
                        
                        // Load sample PDF buttons
                        HStack(spacing: 12) {
                            Button {
                                viewModel.loadSamplePDF(name: "sample-local-pdf")
                            } label: {
                                Text("Sample PDF")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(LinearGradient.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient.accentLight)
                                    )
                            }
                            
                            Button {
                                viewModel.loadSamplePDF(name: "short-pattern")
                            } label: {
                                Text("Short PDF")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(LinearGradient.accentTertiary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient.accentTertiaryLight)
                                    )
                            }
                            
                            Button {
                                viewModel.loadSamplePDF(name: "big-pattern")
                            } label: {
                                Text("Big PDF")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(LinearGradient.accentWarm)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient.accentWarmLight)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Create button
                Button {
                    Task {
                        do {
                            let newProject = try await viewModel.createProject()
                            project = newProject
                            dismiss()
                        } catch {
                            // Error is already handled in viewModel
                        }
                    }
                } label: {
                    ZStack {
                        if viewModel.isFormValid {
                            ZStack {
                                LinearGradient.accent
                                
                                // Inner highlight
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            }
                        } else {
                            LinearGradient.disabled
                        }
                        
                        if viewModel.isCreating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color("AppSurface"))
                        } else {
                            Text("Create Project")
                                .fontWeight(.semibold)
                                .foregroundColor(Color("AppSurface"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.buttonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                }
                .buttonStyle(.plain)
                .enhancedShadow(
                    color: viewModel.isFormValid ? Color("AccentColor") : nil,
                    radius: viewModel.isFormValid ? 12 : 0,
                    y: viewModel.isFormValid ? 6 : 0
                )
                .disabled(!viewModel.isFormValid || viewModel.isCreating)
                .padding(.horizontal)
                .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPicker(selectedURL: $viewModel.selectedPDFURL)
            }
        }
    }
}

#Preview {
    NewProjectView(project: .constant(nil))
}


