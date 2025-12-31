//
//  ProjectError.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import Foundation

/// Custom error types for project-related operations
enum ProjectError: LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case invalidProject
    case fileCopyFailed(Error)
    case documentDirectoryUnavailable
    case pdfLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save projects: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load projects: \(error.localizedDescription)"
        case .invalidProject:
            return "Project file is invalid or missing"
        case .fileCopyFailed(let error):
            return "Failed to copy PDF file: \(error.localizedDescription)"
        case .documentDirectoryUnavailable:
            return "Could not access documents directory"
        case .pdfLoadFailed:
            return "Failed to load PDF file"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .saveFailed:
            return "The project data could not be saved to disk"
        case .loadFailed:
            return "The project data could not be loaded from disk"
        case .invalidProject:
            return "The project file is missing or corrupted"
        case .fileCopyFailed:
            return "The PDF file could not be copied to the app's documents"
        case .documentDirectoryUnavailable:
            return "The app's documents directory is not accessible"
        case .pdfLoadFailed:
            return "The PDF file could not be loaded"
        }
    }
}

