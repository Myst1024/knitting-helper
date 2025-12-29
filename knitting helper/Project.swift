//
//  Project.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import Foundation

/// Codable version of a highlight for persistence
struct CodableHighlight: Identifiable, Codable {
    let id: UUID
    var rectInCanvas: CGRect
    var colorHex: String // Hex color string like "#FF00FF"
    
    init(id: UUID = UUID(), rectInCanvas: CGRect, colorHex: String) {
        self.id = id
        self.rectInCanvas = rectInCanvas
        self.colorHex = colorHex
    }
}

/// Represents a knitting project with a PDF pattern, counters, and highlights
struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var pdfURL: URL
    var counters: [Counter] = []
    var highlights: [CodableHighlight] = []
    
    init(id: UUID = UUID(), name: String, pdfURL: URL, counters: [Counter] = [], highlights: [CodableHighlight] = []) {
        self.id = id
        self.name = name
        self.pdfURL = pdfURL
        self.counters = counters
        self.highlights = highlights
    }
}

// MARK: - Counter Codable Conformance

extension Counter: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, value, max, reps
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Int.self, forKey: .value)
        max = try container.decodeIfPresent(Int.self, forKey: .max)
        reps = try container.decode(Int.self, forKey: .reps)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encode(reps, forKey: .reps)
    }
}

// MARK: - File Management

extension Project {
    /// Copies a PDF file to the app's documents directory and returns the new URL
    static func copyPDFToDocuments(from sourceURL: URL, withName fileName: String) throws -> URL {
        let fileManager = FileManager.default
        
        // Get documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ProjectError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
        }
        
        // Create projects subdirectory if it doesn't exist
        let projectsURL = documentsURL.appendingPathComponent("Projects", isDirectory: true)
        if !fileManager.fileExists(atPath: projectsURL.path) {
            try fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
        }
        
        // Create unique filename
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let destinationURL = projectsURL.appendingPathComponent(uniqueFileName)
        
        // Start accessing security-scoped resource
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Copy the file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    /// Deletes the PDF file associated with this project
    func deletePDF() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: pdfURL)
    }
}

// MARK: - Persistence

extension Project {
    private static var projectsFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("projects.json")
    }
    
    /// Saves an array of projects to disk
    static func saveProjects(_ projects: [Project]) {
        guard let fileURL = projectsFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save projects: \(error)")
        }
    }
    
    /// Loads all projects from disk
    static func loadProjects() -> [Project] {
        guard let fileURL = projectsFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let projects = try JSONDecoder().decode([Project].self, from: data)
            return projects
        } catch {
            print("Failed to load projects: \(error)")
            return []
        }
    }
    
    /// Deletes a project and its PDF file
    func delete() {
        deletePDF()
        var projects = Project.loadProjects()
        projects.removeAll { $0.id == self.id }
        Project.saveProjects(projects)
    }
}
