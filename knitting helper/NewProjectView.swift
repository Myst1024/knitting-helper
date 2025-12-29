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
    
    @State private var projectName: String = "My Project"
    @State private var showDocumentPicker = false
    @State private var selectedPDFURL: URL?
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
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
                
                Text("Create New Project")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    // Project name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("My Project", text: $projectName)
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
                            showDocumentPicker = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.cyan.opacity(0.2), Color.cyan.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: selectedPDFURL == nil ? "doc.badge.plus" : "doc.fill")
                                        .font(.title3)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    if let url = selectedPDFURL {
                                        Text(url.lastPathComponent)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("Tap to change")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Select PDF Pattern")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
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
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.cornerRadius8)
                                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Testing: Load sample PDF
                        Button {
                            if let demoURL = Bundle.main.url(forResource: "sample-local-pdf", withExtension: "pdf") {
                                selectedPDFURL = demoURL
                            }
                        } label: {
                            Text("Use Sample PDF (for testing)")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Create button
                Button {
                    createProject()
                } label: {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Create Project")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Constants.buttonHeight)
                .background(
                    Group {
                        if isFormValid {
                            LinearGradient(
                                colors: [Color.cyan, Color.cyan.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                .shadow(color: isFormValid ? Color.black.opacity(0.2) : Color.clear, radius: 8, y: 4)
                .foregroundColor(.white)
                .disabled(!isFormValid || isCreating)
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
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedURL: $selectedPDFURL)
            }
        }
    }
    
    private var isFormValid: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty && selectedPDFURL != nil
    }
    
    private func createProject() {
        guard let sourceURL = selectedPDFURL else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let copiedURL = try await copyPDF(from: sourceURL)
                let newProject = Project(
                    name: projectName.trimmingCharacters(in: .whitespaces),
                    pdfURL: copiedURL
                )
                
                await MainActor.run {
                    project = newProject
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func copyPDF(from sourceURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileName = sourceURL.lastPathComponent
                    let copiedURL = try Project.copyPDFToDocuments(from: sourceURL, withName: fileName)
                    continuation.resume(returning: copiedURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

#Preview {
    NewProjectView(project: .constant(nil))
}
