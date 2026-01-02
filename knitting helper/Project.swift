//
//  Project.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import Foundation

// MARK: - Constants

private enum FileConstants {
    static let appGroupIdentifier = "group.myst1024.knitting-helper"
    static let projectsDirectory = "Projects"
    static let projectsFileName = "projects.json"
}

// MARK: - Models

/// Codable version of a highlight for persistence
struct CodableHighlight: Identifiable, Codable {
    let id: UUID
    // Represent highlight as page/fraction coordinates so positions are
    // invariant across orientation and scaling. startFraction/endFraction
    // are in 0..1 relative to the page's visible height on the canvas.
    var startPage: Int
    var startFraction: CGFloat
    var endPage: Int
    var endFraction: CGFloat
    var colorHex: String // Hex color string like "#FF00FF"

    init(id: UUID = UUID(), startPage: Int, startFraction: CGFloat, endPage: Int, endFraction: CGFloat, colorHex: String) {
        self.id = id
        self.startPage = startPage
        self.startFraction = startFraction
        self.endPage = endPage
        self.endFraction = endFraction
        self.colorHex = colorHex
    }
}

/// Codable version of a note for persistence
struct CodableNote: Identifiable, Codable, Equatable {
    let id: UUID
    // Represent note position as page/fraction coordinates so positions are
    // invariant across orientation and scaling. xFraction/yFraction are in 0..1
    // relative to the page's width/height on the canvas.
    var page: Int
    var xFraction: CGFloat // 0..1 relative to page width
    var yFraction: CGFloat // 0..1 relative to page height
    var text: String
    var isOpen: Bool // Whether the note editor is currently open
    var width: CGFloat // Note editor width
    var height: CGFloat // Note editor height
    var colorHex: String // Hex color string like "#FF00FF"

    init(id: UUID = UUID(), page: Int, xFraction: CGFloat, yFraction: CGFloat, text: String = "", isOpen: Bool = false, width: CGFloat = 0, height: CGFloat = 0, colorHex: String = "#007AFF") {
        self.id = id
        self.page = page
        self.xFraction = xFraction
        self.yFraction = yFraction
        self.text = text
        self.isOpen = isOpen
        self.width = width
        self.height = height
        self.colorHex = colorHex
    }

    static func == (lhs: CodableNote, rhs: CodableNote) -> Bool {
        return lhs.id == rhs.id && lhs.page == rhs.page &&
               abs(lhs.xFraction - rhs.xFraction) < 0.001 &&
               abs(lhs.yFraction - rhs.yFraction) < 0.001 &&
               lhs.text == rhs.text &&
               lhs.isOpen == rhs.isOpen &&
               abs(lhs.width - rhs.width) < 0.001 &&
               abs(lhs.height - rhs.height) < 0.001 &&
               lhs.colorHex == rhs.colorHex
    }
}

/// Codable version of a bookmark for persistence
struct CodableBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    // Represent bookmark position as page/fraction coordinates so positions are
    // invariant across orientation and scaling. xFraction/yFraction are in 0..1
    // relative to the page's width/height on the canvas.
    var page: Int
    var xFraction: CGFloat // 0..1 relative to page width
    var yFraction: CGFloat // 0..1 relative to page height
    var name: String
    var colorHex: String // Hex color string like "#FF00FF"

    init(id: UUID = UUID(), page: Int, xFraction: CGFloat, yFraction: CGFloat, name: String = "", colorHex: String = "#FF9500") {
        self.id = id
        self.page = page
        self.xFraction = xFraction
        self.yFraction = yFraction
        self.name = name
        self.colorHex = colorHex
    }

    static func == (lhs: CodableBookmark, rhs: CodableBookmark) -> Bool {
        return lhs.id == rhs.id && lhs.page == rhs.page &&
               abs(lhs.xFraction - rhs.xFraction) < 0.001 &&
               abs(lhs.yFraction - rhs.yFraction) < 0.001 &&
               lhs.name == rhs.name &&
               lhs.colorHex == rhs.colorHex
    }
}

/// Represents a knitting project with a PDF pattern, counters, highlights, notes, and bookmarks
struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var pdfURL: URL
    var counters: [Counter] = []
    var highlights: [CodableHighlight] = []
    var notes: [CodableNote] = []
    var bookmarks: [CodableBookmark] = []
    var scrollOffsetY: Double = 0
    var timerElapsedSeconds: Double = 0
    var timerLastStartTime: Date?
    var lastWorkedOnDate: Date?
    
    init(id: UUID = UUID(), name: String, pdfURL: URL, counters: [Counter] = [], highlights: [CodableHighlight] = [], notes: [CodableNote] = [], bookmarks: [CodableBookmark] = [], scrollOffsetY: Double = 0, timerElapsedSeconds: Double = 0, timerLastStartTime: Date? = nil, lastWorkedOnDate: Date? = nil) {
        self.id = id
        self.name = name
        self.pdfURL = pdfURL
        self.counters = counters
        self.highlights = highlights
        self.notes = notes
        self.bookmarks = bookmarks
        self.scrollOffsetY = scrollOffsetY
        self.timerElapsedSeconds = timerElapsedSeconds
        self.timerLastStartTime = timerLastStartTime
        self.lastWorkedOnDate = lastWorkedOnDate
    }
    
    /// Checks if the project's PDF file still exists
    var isValid: Bool {
        FileManager.default.fileExists(atPath: pdfURL.path)
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
    private static var documentsDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FileConstants.appGroupIdentifier)
    }
    
    private static var projectsDirectory: URL? {
        documentsDirectory?.appendingPathComponent(FileConstants.projectsDirectory, isDirectory: true)
    }
    
    /// Copies a PDF file to the app's documents directory and returns the new URL
    static func copyPDFToDocuments(from sourceURL: URL, withName fileName: String) throws -> URL {
        let fileManager = FileManager.default
        
        guard let projectsURL = projectsDirectory else {
            throw ProjectError.documentDirectoryUnavailable
        }
        
        // Create projects subdirectory if needed
        if !fileManager.fileExists(atPath: projectsURL.path) {
            try fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
        }
        
        // Create unique filename
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let destinationURL = projectsURL.appendingPathComponent(uniqueFileName)
        
        // Access and copy the file
        defer {
            if sourceURL.startAccessingSecurityScopedResource() {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        _ = sourceURL.startAccessingSecurityScopedResource()
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
        documentsDirectory?.appendingPathComponent(FileConstants.projectsFileName)
    }
    
    /// Saves an array of projects to disk
    static func saveProjects(_ projects: [Project]) throws {
        guard let fileURL = projectsFileURL else {
            throw ProjectError.documentDirectoryUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ProjectError.saveFailed(error)
        }
    }
    
    /// Loads all projects from disk and validates them
    static func loadProjects() -> [Project] {
        guard let fileURL = projectsFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let projects = try JSONDecoder().decode([Project].self, from: data)
            
            // Filter out invalid projects (missing PDF files)
            let validProjects = projects.filter { $0.isValid }
            
            // If any projects were invalid, save the cleaned list
            if validProjects.count != projects.count {
                print("Removed \(projects.count - validProjects.count) invalid project(s) with missing PDF files")
                try? saveProjects(validProjects)
            }
            
            return validProjects
        } catch {
            print("Failed to load projects: \(error)")
            return []
        }
    }
    
    /// Deletes this project and its PDF file
    func delete() {
        deletePDF()
        var projects = Project.loadProjects()
        projects.removeAll { $0.id == self.id }
        try? Project.saveProjects(projects)
    }
}
