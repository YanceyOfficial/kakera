import SwiftUI

/// Words found in a picture or in shared text, as chips to pick from before they go to the
/// deck: the add-words sheet's scan and the share extension both end here. Tapping a chip
/// toggles it; the toolbar adds the picked ones, in the order they were found.
public struct WordPickerSheet: View {
    private let words: [String]
    private let footnote: String
    private let onCancel: () -> Void
    private let onAdd: ([String]) -> Void

    @State private var selection: Set<String>

    /// - Parameters:
    ///   - words: the candidates, in reading order.
    ///   - preselected: whether every word starts picked — right for a few shared words,
    ///     wrong for a whole scanned page.
    ///   - footnote: where the words go next, under the chips.
    public init(
        words: [String], preselected: Bool, footnote: String,
        onCancel: @escaping () -> Void, onAdd: @escaping ([String]) -> Void
    ) {
        self.words = words
        self.footnote = footnote
        self.onCancel = onCancel
        self.onAdd = onAdd
        _selection = State(initialValue: preselected ? Set(words) : [])
    }

    private var picked: [String] { words.filter { selection.contains($0) } }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KakeraSpacing.m) {
                    Text("\(words.count) word\(words.count == 1 ? "" : "s") found. Tap the ones to add.")
                        .font(KakeraFont.body(15))
                        .foregroundStyle(KakeraColor.inkSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(words, id: \.self) { word in
                            chip(word)
                        }
                    }
                    Text(footnote)
                        .font(KakeraFont.body(13))
                        .foregroundStyle(KakeraColor.inkSecondary)
                        .padding(.top, KakeraSpacing.s)
                }
                .padding(KakeraSpacing.l)
            }
            .background(KakeraColor.washi)
            .navigationTitle("Add words")
            .inlineTitle()
            .safeAreaInset(edge: .bottom) {
                KakeraPrimaryButton(picked.isEmpty ? "Add" : "Add \(picked.count)") { onAdd(picked) }
                    .disabled(picked.isEmpty)
                    .opacity(picked.isEmpty ? 0.5 : 1)
                    .padding(KakeraSpacing.l)
                    .background(KakeraColor.washi)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(selection.count == words.count ? "Clear" : "Select all") {
                        selection = selection.count == words.count ? [] : Set(words)
                    }
                }
            }
        }
        .tint(KakeraColor.accent)
    }

    private func chip(_ word: String) -> some View {
        let on = selection.contains(word)
        return Button {
            KakeraHaptics.selection()
            if on { selection.remove(word) } else { selection.insert(word) }
        } label: {
            Text(word)
                .font(KakeraFont.body(16, weight: .medium))
                .foregroundStyle(on ? Color.white : KakeraColor.sumi)
                .padding(.horizontal, KakeraSpacing.m)
                .padding(.vertical, KakeraSpacing.s)
                .background(Capsule().fill(on ? KakeraColor.accent : KakeraColor.cardFace))
                .overlay(Capsule().strokeBorder(on ? KakeraColor.accent : KakeraColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private extension View {
    /// The compact title (iOS); a no-op where the modifier doesn't exist (the package builds on macOS for its tests).
    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
