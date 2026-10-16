import SwiftUI

/// A learner's self-rating after seeing the answer (maps to FSRS grades in the app).
public enum ReviewRating: String, CaseIterable, Sendable {
    case again, hard, good, easy

    public var label: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    /// Restrained, difficulty-coded tint per rating (red → amber → pine → blue).
    var tint: Color {
        switch self {
        case .again: return KaiColor.danger
        // Muted in light mode; lifted in dark, where the muted tones sank into the glass.
        case .hard: return adaptive(light: 0xB07A2E, dark: 0xE0A553)   // amber
        case .good: return adaptive(light: 0x3E7C63, dark: 0x62B690)   // pine
        case .easy: return adaptive(light: 0x3E6D8C, dark: 0x72A6CC)   // slate blue
        }
    }
}

/// The four-way rating row shown once the card is revealed (Liquid Glass on iOS 26): consistent soft-tinted
/// cards, color-coded by difficulty, each with an optional next-interval caption so the
/// learner knows what each choice schedules.
public struct RatingBar: View {
    private let onRate: (ReviewRating) -> Void
    private let interval: (ReviewRating) -> String?
    private let axis: Axis

    /// - Parameter interval: returns the next-review interval caption for a rating
    ///   (e.g. "1d"), or nil to omit it.
    ///   - axis: a row under the card, or a column beside it (a screen on its side).
    public init(
        axis: Axis = .horizontal,
        interval: @escaping (ReviewRating) -> String? = { _ in nil },
        onRate: @escaping (ReviewRating) -> Void
    ) {
        self.axis = axis
        self.interval = interval
        self.onRate = onRate
    }

    public var body: some View {
        if #available(iOS 26, macOS 26, *) {
            // Liquid Glass, as the system's own controls are: one glass container so the
            // four read as a group (and merge as they press), each rating in its colour.
            GlassEffectContainer(spacing: KaiSpacing.s) {
                stack {
                    ForEach(ReviewRating.allCases, id: \.self) { rating in
                        Button { rate(rating) } label: {
                            // The glass style pads the label itself; this keeps the
                            // capsule about as tall as the other controls on screen.
                            label(rating)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
        } else {
            stack {
                ForEach(ReviewRating.allCases, id: \.self) { rating in
                    Button { rate(rating) } label: {
                        label(rating)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(rating.tint.opacity(0.14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(rating.tint.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(KaiPressStyle())
                }
            }
        }
    }

    private var stack: AnyLayout {
        axis == .horizontal ? AnyLayout(HStackLayout(spacing: KaiSpacing.s)) : AnyLayout(VStackLayout(spacing: KaiSpacing.s))
    }

    private func rate(_ rating: ReviewRating) {
        // "Again" earns a firmer thud; the rest get a crisp selection tick.
        if rating == .again { KaiHaptics.impact(.rigid) } else { KaiHaptics.selection() }
        onRate(rating)
    }

    private func label(_ rating: ReviewRating) -> some View {
        VStack(spacing: 2) {
            Text(rating.label)
                .font(KaiFont.body(15, weight: .semibold))
                .foregroundStyle(rating.tint)
            if let caption = interval(rating), !caption.isEmpty {
                Text(caption)
                    .font(KaiFont.body(11, weight: .medium))
                    .foregroundStyle(rating.tint.opacity(0.7))
            }
        }
    }
}

/// A thin ink track with an accent fill showing session progress (0...1).
public struct SessionProgressBar: View {
    private let progress: Double
    public init(progress: Double) { self.progress = min(max(progress, 0), 1) }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(KaiColor.hairline)
                Capsule()
                    .fill(KaiColor.accent)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
        .animation(KaiMotion.standard, value: progress)
    }
}

/// A full-width ink primary button (e.g. "Show answer").
public struct KaiPrimaryButton: View {
    private let title: String
    private let action: () -> Void
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button {
            KaiHaptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(KaiFont.body(17, weight: .semibold))
                .foregroundStyle(KaiColor.cardFace)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(KaiColor.sumi)
                )
        }
        .buttonStyle(KaiPressStyle())
    }
}
