//
//  ViewExtensions.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

// MARK: - Gradient Extensions

extension LinearGradient {
    /// Standard accent gradient used throughout the app
    static var accent: LinearGradient {
        LinearGradient(
            colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Light accent gradient for backgrounds
    static var accentLight: LinearGradient {
        LinearGradient(
            colors: [Color("AccentColor").opacity(0.18), Color("AccentColor").opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Disabled/gray gradient for inactive states
    static var disabled: LinearGradient {
        LinearGradient(
            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Shape Extensions

extension Shape {
    /// Applies the light accent gradient as a fill
    func accentGradientFill() -> some View {
        self.fill(LinearGradient.accentLight)
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the standard accent gradient as a foreground style
    func accentGradient() -> some View {
        self.foregroundStyle(LinearGradient.accent)
    }
    
    /// Dismisses keyboard when tapped
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

// MARK: - Utility Functions

enum UIHelper {
    /// Gets the bottom safe area inset
    static func safeAreaBottomInset() -> CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return 0 }
        return window.safeAreaInsets.bottom
    }
}

// MARK: - Button Styles

struct AccentButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color("AppSurface"))
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient.accent
                    } else {
                        LinearGradient.disabled
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: isEnabled ? Color("AppText").opacity(0.25) : Color.clear,
                radius: 12,
                y: 6
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static func accent(isEnabled: Bool = true) -> AccentButtonStyle {
        AccentButtonStyle(isEnabled: isEnabled)
    }
}

