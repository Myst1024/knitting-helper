//
//  BookmarkListView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/31/25.
//

import SwiftUI

struct BookmarkListView: View {
    @Binding var isPresented: Bool
    let bookmarks: [CodableBookmark]
    let onSelectBookmark: (CodableBookmark) -> Void
    let onCreateNewBookmark: () -> Void
    let onRecolorBookmark: (CodableBookmark) -> Void
    let onDeleteBookmark: (CodableBookmark) -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Sliding panel from bottom
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // Handle indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 6)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Title
                    Text("Bookmarks")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Bookmark list
                    if bookmarks.isEmpty {
                        Text("No bookmarks yet")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(bookmarks) { bookmark in
                                    Button(action: {
                                        onSelectBookmark(bookmark)
                                        isPresented = false
                                    }) {
                                        HStack {
                                            // Bookmark icon
                                            Image(systemName: "bookmark.fill")
                                                .foregroundColor(Color(UIColor(hex: bookmark.colorHex) ?? .systemOrange))
                                                .frame(width: 24, height: 24)

                                            // Bookmark name
                                            Text(bookmark.name)
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            // Page indicator and action buttons
                                            HStack(spacing: 8) {
                                                Text("Page \(bookmark.page + 1)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                // Recolor button
                                                Button(action: {
                                                    onRecolorBookmark(bookmark)
                                                }) {
                                                    Image(systemName: "paintpalette")
                                                        .foregroundColor(Color(UIColor(hex: bookmark.colorHex) ?? .systemOrange))
                                                        .frame(width: 24, height: 24)
                                                }

                                                // Delete button
                                                Button(action: {
                                                    onDeleteBookmark(bookmark)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            onDeleteBookmark(bookmark)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            onRecolorBookmark(bookmark)
                                            isPresented = false
                                        } label: {
                                            Label("Recolor", systemImage: "paintpalette")
                                        }
                                        .tint(.blue)
                                    }

                                    // Separator line
                                    Divider()
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }

                    // Create new bookmark button
                    Button(action: {
                        onCreateNewBookmark()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.accentColor)
                                .frame(width: 24, height: 24)

                            Text("Create New Bookmark")
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }

                    // Bottom padding
                    Color.clear
                        .frame(height: UIHelper.safeAreaBottomInset() + 20)
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
            }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: isPresented)
        }
        .animation(.easeInOut, value: isPresented)
    }
}

// Helper extension for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
