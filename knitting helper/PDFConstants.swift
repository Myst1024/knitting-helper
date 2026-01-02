//
//  PDFConstants.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit

enum PDFConstants {
    static let defaultHighlightHeight: CGFloat = 120
    static let highlightOpacity: CGFloat = 0.35
    static let selectedHighlightOpacity: CGFloat = 0.6
    static let highlightStrokeWidth: CGFloat = 2.0
    static let handleWidth: CGFloat = 80
    static let handleHeight: CGFloat = 8
    static let handleCornerRadius: CGFloat = 4
    static let handleStrokeWidth: CGFloat = 1.0
    static let deleteButtonSize: CGFloat = 28
    static let deleteButtonInset: CGFloat = 8
    static let deleteButtonOffset: CGFloat = 12
    static let deleteIconOpacity: CGFloat = 0.9
    static let colorPickerButtonSize: CGFloat = 28
    static let colorPickerButtonSpacing: CGFloat = 8
    static let highlightTapHitSlop: CGFloat = 10
    static let minHighlightHeight: CGFloat = 30
    // Base hit slop applied uniformly; additional asymmetric extras below
    static let handleHitSlop: CGFloat = 10
    // Extra horizontal expansion applied to handle hit areas (left & right)
    static let handleHitExtraHorizontal: CGFloat = 10
    // Extra vertical expansion for top and bottom handles
    static let handleHitExtraTop: CGFloat = 20
    static let handleHitExtraBottom: CGFloat = 20
    
    // PDF rendering constants
    static let counterHeight: CGFloat = 66 // Approximate height per counter
    static let minimumZoomScale: CGFloat = 0.5
    static let maximumZoomScale: CGFloat = 4.0
    static let imageCacheLimit: Int = 150 * 1024 * 1024 // ~150 MB
    
    // Note constants
    static let noteIconSize: CGFloat = 26
    static let noteIconTapHitSlop: CGFloat = 12
    static let noteEditorMinWidth: CGFloat = 120
    static let noteEditorMaxWidth: CGFloat = 350
    static let noteEditorMinHeight: CGFloat = 40
    static let noteEditorMaxHeight: CGFloat = 300
    static let noteEditorDefaultWidth: CGFloat = 200
    static let noteEditorDefaultHeight: CGFloat = 120
    static let noteEditorResizeHandleSize: CGFloat = 20

    // Bookmark constants
    static let bookmarkIconSize: CGFloat = 28
}

