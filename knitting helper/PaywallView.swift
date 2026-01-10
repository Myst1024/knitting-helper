import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    var product: Product?

    @Environment(\.dismiss) private var dismiss
    @State private var sparkles: [Sparkle] = []

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color("AccentWarm"), Color("AccentSecondary"), Color("AccentTertiary")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var surfaceColor: Color { Color("AppSurface") }
    private var textColor: Color { Color("AppText") }

    var body: some View {
        ZStack {
            accentGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Unlock Premium")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .padding(.top, 20)
                
                Spacer()

                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        featureRow(icon: "bookmark.fill", title: "Bookmarks", subtitle: "Save your place across PDFs")
                        featureRow(icon: "highlighter", title: "Color Highlights", subtitle: "Mark rows with custom colors")
                        featureRow(icon: "note.text", title: "Notes", subtitle: "Keep project notes in one place")
                    }
                    .padding()
                    .background(surfaceColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let product {
                        Text(product.displayPrice)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 4)
                    }

                    Button(action: {
                        Task { await purchaseManager.purchasePremium() }
                    }) {
                        Text("Go Premium")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color("AccentColor"), Color("AccentSecondary")], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
                    }
                    .overlay(alignment: .center) {
                        SparkleEffect(sparkles: $sparkles)
                    }
                    .onAppear {
                        startSparkles()
                    }

                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Task { await purchaseManager.restorePurchases() }
                        }
                        .foregroundColor(.white.opacity(0.9))

                        Button("Maybe Later") {
                            purchaseManager.isPaywallPresented = false
                            dismiss()
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
    }

    private func startSparkles() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            let angle = Double.random(in: 0..<2 * .pi)
            let horizontalRadius: CGFloat = 185
            let verticalRadius: CGFloat = 50
            let x = horizontalRadius * cos(angle)
            let y = verticalRadius * sin(angle)
            
            let sparkle = Sparkle(
                x: x,
                y: y,
                opacity: 1.0,
                scale: 1.0
            )
            sparkles.append(sparkle)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                sparkles.removeAll { $0.id == sparkle.id }
            }
            
            withAnimation(.easeOut(duration: 0.8)) {
                if let index = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                    sparkles[index].opacity = 0
                    sparkles[index].scale = 0.5
                }
            }
        }
    }
}

struct Sparkle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    var scale: CGFloat
}

struct SparkleEffect: View {
    @Binding var sparkles: [Sparkle]

    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 1.0, green: 0.92, blue: 0.016))
                    .offset(x: sparkle.x, y: sparkle.y)
                    .opacity(sparkle.opacity)
                    .scaleEffect(sparkle.scale)
            }
        }
        .allowsHitTesting(false)
    }
}
