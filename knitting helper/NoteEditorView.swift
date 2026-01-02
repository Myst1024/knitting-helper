//
//  NoteEditorView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import SwiftUI

struct NoteEditorView: View {
    @Binding var text: String
    @Binding var size: CGSize
    let noteID: UUID
    let noteColor: Color
    let onDelete: () -> Void
    let onColorPicker: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Text editor - main content, white background
            TextEditor(text: $text)
                .focused($isFocused)
                .autocorrectionDisabled(true)
                .font(.system(size: 12)) // Smaller font
                .padding(4)
                .background(Color.white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .frame(width: size.width, height: size.height)
                .scrollContentBackground(.hidden) // Hide default background
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            // Delete button - protrudes from top-right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            )
                    }
                    .offset(x: 4, y: -4)
                }
                Spacer()
            }
            
            // Color picker button in bottom-left corner
            VStack {
                Spacer()
                HStack {
                    Button {
                        onColorPicker()
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 10))
                            .foregroundColor(noteColor)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            )
                    }
                    .offset(x: -4, y: 4)
                    Spacer()
                }
            }
            
            // Resize handle in bottom-right corner - protrudes
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: PDFConstants.noteEditorResizeHandleSize - 4, height: PDFConstants.noteEditorResizeHandleSize - 4)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                        .offset(x: 4, y: 4)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.none, value: size) // Disable animation to prevent visual lag
        .colorScheme(.light) // Force light mode
    }
}

