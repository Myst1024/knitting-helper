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
            colors: [Color("AccentColor"), Color("AccentColor").opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Secondary accent gradient (purple)
    static var accentSecondary: LinearGradient {
        LinearGradient(
            colors: [Color("AccentSecondary"), Color("AccentSecondary").opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Tertiary accent gradient (teal)
    static var accentTertiary: LinearGradient {
        LinearGradient(
            colors: [Color("AccentTertiary"), Color("AccentTertiary").opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Warm accent gradient (coral/orange)
    static var accentWarm: LinearGradient {
        LinearGradient(
            colors: [Color("AccentWarm"), Color("AccentWarm").opacity(0.75)],
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
    
    /// Light secondary gradient for backgrounds
    static var accentSecondaryLight: LinearGradient {
        LinearGradient(
            colors: [Color("AccentSecondary").opacity(0.15), Color("AccentSecondary").opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Light tertiary gradient for backgrounds
    static var accentTertiaryLight: LinearGradient {
        LinearGradient(
            colors: [Color("AccentTertiary").opacity(0.15), Color("AccentTertiary").opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Light warm gradient for backgrounds
    static var accentWarmLight: LinearGradient {
        LinearGradient(
            colors: [Color("AccentWarm").opacity(0.15), Color("AccentWarm").opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle background gradient
    static var backgroundSubtle: LinearGradient {
        LinearGradient(
            colors: [
                Color("AppBackground"),
                Color("AppBackground").opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Multi-color gradient for special elements
    static var rainbowSubtle: LinearGradient {
        LinearGradient(
            colors: [
                Color("AccentColor").opacity(0.12),
                Color("AccentSecondary").opacity(0.08),
                Color("AccentTertiary").opacity(0.10)
            ],
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
    
    /// Applies a gradient fill based on index for variety
    func gradientFill(for index: Int) -> some View {
        let gradient: LinearGradient
        switch index % 4 {
        case 0:
            gradient = LinearGradient.accentLight
        case 1:
            gradient = LinearGradient.accentSecondaryLight
        case 2:
            gradient = LinearGradient.accentTertiaryLight
        default:
            gradient = LinearGradient.accentWarmLight
        }
        return self.fill(gradient)
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the standard accent gradient as a foreground style
    func accentGradient() -> some View {
        self.foregroundStyle(LinearGradient.accent)
    }
    
    /// Applies a gradient foreground style based on index for variety
    func gradientForeground(for index: Int) -> some View {
        let gradient: LinearGradient
        switch index % 4 {
        case 0:
            gradient = LinearGradient.accent
        case 1:
            gradient = LinearGradient.accentSecondary
        case 2:
            gradient = LinearGradient.accentTertiary
        default:
            gradient = LinearGradient.accentWarm
        }
        return self.foregroundStyle(gradient)
    }
    
    /// Adds enhanced shadow for depth
    func enhancedShadow(color: Color? = nil, radius: CGFloat = 8, y: CGFloat = 4) -> some View {
        self.shadow(
            color: (color ?? Color("AppText")).opacity(0.12),
            radius: radius,
            x: 0,
            y: y
        )
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

