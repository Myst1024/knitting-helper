//
//  NewProjectViewModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import Combine

/// View model for creating a new project
@MainActor
class NewProjectViewModel: ObservableObject {
    @Published var projectName: String = "My Project"
    @Published var showDocumentPicker = false
    @Published var selectedPDFURL: URL?
    @Published var isCreating = false
    @Published var errorMessage: String?
    
    var isFormValid: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty && selectedPDFURL != nil
    }
    
    // MARK: - PDF Selection
    
    func loadSamplePDF(name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "pdf") {
            selectedPDFURL = url
        }
    }
    
    // MARK: - Project Creation
    
    func createProject() async throws -> Project {
        guard let sourceURL = selectedPDFURL else {
            throw ProjectError.pdfLoadFailed
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            let copiedURL = try await copyPDF(from: sourceURL)
            let newProject = Project(
                name: projectName.trimmingCharacters(in: .whitespaces),
                pdfURL: copiedURL,
                lastWorkedOnDate: Date()
            )
            
            isCreating = false
            return newProject
        } catch {
            isCreating = false
            let projectError: ProjectError
            if let existingError = error as? ProjectError {
                projectError = existingError
            } else {
                projectError = .fileCopyFailed(error)
            }
            errorMessage = projectError.localizedDescription
            throw projectError
        }
    }
    
    // MARK: - Private Helpers
    
    private func copyPDF(from sourceURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    let fileName = sourceURL.lastPathComponent
                    let copiedURL = try await Project.copyPDFToDocuments(from: sourceURL, withName: fileName)
                    continuation.resume(returning: copiedURL)
                } catch {
                    let projectError: ProjectError
                    if let existingError = error as? ProjectError {
                        projectError = existingError
                    } else {
                        projectError = .fileCopyFailed(error)
                    }
                    continuation.resume(throwing: projectError)
                }
            }
        }
    }
}

