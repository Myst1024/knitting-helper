//
//  NewProjectView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import SwiftUI

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
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                    .padding(.top, 40)
                
                Text("Create New Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                
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
                            HStack {
                                Image(systemName: selectedPDFURL == nil ? "doc.badge.plus" : "doc.fill")
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    if let url = selectedPDFURL {
                                        Text(url.lastPathComponent)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text("Tap to change")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Select PDF Pattern")
                                            .font(.body)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
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
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canCreate ? Color.purple : Color.gray.opacity(0.3))
                )
                .foregroundColor(.white)
                .disabled(!canCreate || isCreating)
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
    
    private var canCreate: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty && selectedPDFURL != nil
    }
    
    private func createProject() {
        guard let sourceURL = selectedPDFURL else { return }
        
        isCreating = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Copy PDF to documents directory
                let fileName = sourceURL.lastPathComponent
                let copiedURL = try Project.copyPDFToDocuments(from: sourceURL, withName: fileName)
                
                // Create project
                let newProject = Project(
                    name: projectName.trimmingCharacters(in: .whitespaces),
                    pdfURL: copiedURL
                )
                
                DispatchQueue.main.async {
                    project = newProject
                    isCreating = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isCreating = false
                    errorMessage = "Failed to create project: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NewProjectView(project: .constant(nil))
}
