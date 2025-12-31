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
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .accentGradientFill()
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: Constants.iconSize))
                        .accentGradient()
                }
                .padding(.top, 40)
                
                Text("Create New Project")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                                    Circle()
                                        .accentGradientFill()
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: viewModel.selectedPDFURL == nil ? "doc.badge.plus" : "doc.fill")
                                        .font(.title3)
                                        .accentGradient()
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
                                RoundedRectangle(cornerRadius: Constants.cornerRadius8)
                                    .fill(Color("AppSurface"))
                                    .shadow(color: Color("AppText").opacity(0.06), radius: 8, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.cornerRadius8)
                                    .stroke(Color("AppSeparator"), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Load sample PDF
                        Button {
                            viewModel.loadSamplePDF(name: "sample-local-pdf")
                        } label: {
                            Text("Sample PDF")
                                .font(.caption)
                                .foregroundColor(Color("AccentColor"))
                        }

                        // Load short PDF
                        Button {
                            viewModel.loadSamplePDF(name: "short-pattern")
                        } label: {
                            Text("Short PDF")
                                .font(.caption)
                                .foregroundColor(Color("AccentColor"))
                        }

                        // Load big PDF
                        Button {
                            viewModel.loadSamplePDF(name: "big-pattern")
                        } label: {
                            Text("Big PDF")
                                .font(.caption)
                                .foregroundColor(Color("AccentColor"))
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
                            LinearGradient.accent
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
                .shadow(color: viewModel.isFormValid ? Color("AppText").opacity(0.2) : Color.clear, radius: 8, y: 4)
                .disabled(!viewModel.isFormValid || viewModel.isCreating)
                .padding(.horizontal)
                .padding(.bottom, 20)
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


