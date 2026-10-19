import SwiftUI

/// Visual intent of a toast.
public enum KakeraToastStyle: Sendable {
    case success
    case error

    var background: Color {
        switch self {
        case .success: return KakeraColor.sumi
        case .error: return KakeraColor.danger
        }
    }

    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

/// A small pill used for transient feedback (e.g. "Note added", "Couldn't save").
public struct KakeraToast: View {
    private let message: String
    private let style: KakeraToastStyle

    public init(_ message: String, style: KakeraToastStyle = .success) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        HStack(spacing: KakeraSpacing.s) {
            Image(systemName: style.symbol)
            Text(message)
        }
        .font(KakeraFont.body(15, weight: .semibold))
        .foregroundStyle(KakeraColor.cardFace)
        .padding(.horizontal, KakeraSpacing.l)
        .padding(.vertical, KakeraSpacing.m)
        .background(Capsule().fill(style.background))
        .shadow(color: KakeraColor.shadow, radius: 12, x: 0, y: 6)
    }
}

public extension View {
    /// Presents a transient toast from the top edge that auto-dismisses.
    func kakeraToast(_ message: String, style: KakeraToastStyle = .success, isPresented: Binding<Bool>, duration: Double = 1.8) -> some View {
        overlay(alignment: .top) {
            if isPresented.wrappedValue {
                KakeraToast(message, style: style)
                    .padding(.top, KakeraSpacing.xl)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                        withAnimation(.easeInOut) { isPresented.wrappedValue = false }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
    }
}
