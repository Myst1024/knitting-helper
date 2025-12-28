# Knitting Helper - Copilot Instructions

## Project Overview
Knitting Helper is an iOS application designed to help knitters view and manage their knitting patterns in PDF format. The app provides a simple, user-friendly interface for selecting and displaying PDF knitting patterns on iOS devices.

## Technology Stack
- **Language**: Swift 5.0
- **Framework**: SwiftUI (iOS 26.2+)
- **Platform**: iOS only (iPhone and iPad)
- **Target Devices**: iPhone (1), iPad (2)
- **Key Frameworks**: PDFKit, UIKit, UniformTypeIdentifiers

## Architecture & File Structure

### Main Files
1. **knitting_helperApp.swift** - App entry point using SwiftUI App lifecycle
2. **ContentView.swift** - Main view with navigation and PDF selection UI
3. **PDFViewer.swift** - SwiftUI wrapper for PDFKit's PDFView
4. **DocumentPicker.swift** - SwiftUI wrapper for UIDocumentPickerViewController

## Code Standards & Conventions

### General Guidelines
- Use SwiftUI for all UI components
- Follow Swift naming conventions (camelCase for variables/functions, PascalCase for types)
- Always include proper imports at the top of files
- Use `@State` for local view state, `@Binding` for passed state
- Prefer struct over class for SwiftUI views
- Use `// MARK:` comments to organize code sections

### Import Requirements
**CRITICAL**: All files using UIKit types MUST include these imports in this order:
```swift
import SwiftUI
import UIKit  // Required for UIViewRepresentable, UIViewControllerRepresentable
import [other frameworks as needed]
```

### UIKit Integration
- Use `UIViewRepresentable` to wrap UIKit views (e.g., PDFView)
- Use `UIViewControllerRepresentable` to wrap UIKit view controllers (e.g., UIDocumentPickerViewController)
- Always implement required methods: `makeUIView/makeUIViewController` and `updateUIView/updateUIViewController`
- Use Coordinator pattern for delegate callbacks

### File Management
- Copy selected PDFs to app's documents directory for persistent access
- Always handle security-scoped resources properly:
  - Call `startAccessingSecurityScopedResource()` before accessing
  - Call `stopAccessingSecurityScopedResource()` after use
- Remove existing files before copying to avoid conflicts

### Error Handling
- Use `do-catch` blocks for file operations
- Print errors to console for debugging
- Handle edge cases (no file selected, file already exists, etc.)

## Feature Implementation Guidelines

### PDF Selection
- Use `UIDocumentPickerViewController` with `UTType.pdf` content type
- Disable multiple selection for simplicity
- Implement delegate methods to handle selection and cancellation
- Automatically dismiss picker after selection or cancellation

### PDF Display
- Use PDFKit's `PDFView` for rendering
- Configure with these settings:
  - `autoScales = true` for responsive sizing
  - `displayMode = .singlePageContinuous` for smooth scrolling
  - `displayDirection = .vertical` for natural reading flow

### Navigation & UI
- Use `NavigationView` for top-level navigation
- Show empty state when no PDF is loaded (icon + message + button)
- Add toolbar button to change patterns when PDF is loaded
- Use `.sheet(isPresented:)` for modal document picker

## Common Patterns

### State Management
```swift
@State private var selectedPDFURL: URL?
@State private var showDocumentPicker = false
```

### Modal Presentation
```swift
.sheet(isPresented: $showDocumentPicker) {
    DocumentPicker(selectedURL: $selectedPDFURL)
}
```

### Environment Dismiss
```swift
@Environment(\.dismiss) private var dismiss
// Later: dismiss()
```

## Build Configuration
- **SDKROOT**: iphoneos
- **SUPPORTED_PLATFORMS**: iphoneos, iphonesimulator
- **IPHONEOS_DEPLOYMENT_TARGET**: 26.2
- **TARGETED_DEVICE_FAMILY**: 1,2 (iPhone, iPad)
- **ENABLE_APP_SANDBOX**: YES
- **ENABLE_USER_SELECTED_FILES**: readonly

## Future Enhancements (Ideas)
- Row/stitch counter functionality
- Pattern annotations and notes
- Multiple pattern management
- Dark mode optimization
- Pattern favorites/organization
- Export/share patterns
- iCloud sync for patterns
