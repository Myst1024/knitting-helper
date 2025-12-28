//
//  ContentView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedPDFURL: URL?
    @State private var showDocumentPicker = false
    @State private var shouldAddHighlight = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let pdfURL = selectedPDFURL {
                    // Fixed toolbar at the top
                    HStack(spacing: 16) {
                        Button {
                            shouldAddHighlight = true
                        } label: {
                            Image(systemName: "highlighter")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                    
                    PDFViewer(url: pdfURL, shouldAddHighlight: $shouldAddHighlight)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)
                        Text("No pattern loaded")
                            .font(.title2)
                        Button("Select PDF Pattern") {
                            showDocumentPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Open Demo PDF") {
                            if let demoURL = Bundle.main.url(forResource: "sample-local-pdf", withExtension: "pdf") {
                                selectedPDFURL = demoURL
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Knitting Helper")
            .toolbar {
                if selectedPDFURL != nil {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Change Pattern", systemImage: "doc.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedURL: $selectedPDFURL)
            }
        }
    }
}

#Preview {
    ContentView()
}
