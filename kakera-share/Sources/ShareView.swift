import SwiftUI
import UniformTypeIdentifiers
import KakeraServices
import KakeraUI

/// Reads what was shared — text, or a picture to recognize text in — and offers its words
/// as chips. The picked ones go to the inbox in the App Group, where the app finds them
/// the next time it comes to the front and opens its add-words sheet on them. Everything
/// happens on the device; the extension has no key and sends nothing.
struct ShareView: View {
    let context: NSExtensionContext?

    private enum Phase {
        case reading
        case words([String], preselected: Bool)
        case nothing(String)
    }

    @State private var phase: Phase = .reading

    var body: some View {
        Group {
            switch phase {
            case .reading:
                ProgressView("Reading…")
                    .tint(KakeraColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KakeraColor.washi)
            case .words(let words, let preselected):
                WordPickerSheet(
                    words: words, preselected: preselected,
                    footnote: "They wait in Kakera's Words tab, ready to generate as cards."
                ) {
                    context?.cancelRequest(withError: CocoaError(.userCancelled))
                } onAdd: { picked in
                    WordInbox().add(picked)
                    context?.completeRequest(returningItems: nil)
                }
            case .nothing(let reason):
                NavigationStack {
                    ContentUnavailableView(reason, systemImage: "text.viewfinder")
                        .background(KakeraColor.washi)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { context?.cancelRequest(withError: CocoaError(.userCancelled)) }
                            }
                        }
                }
                .tint(KakeraColor.accent)
            }
        }
        .task { await read() }
    }

    /// The deck being studied, as the app last published it for the widget.
    private var language: CandidateLanguage {
        WidgetSnapshotStore().read()?.language == "japanese" ? .japanese : .english
    }

    private func read() async {
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var lines: [String] = []
        var sharedText = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await text(from: provider) {
                    lines += text.components(separatedBy: .newlines)
                    sharedText = true
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let data = await data(from: provider) {
                    let recognizer = VisionTextRecognizer(languages: language == .japanese ? ["ja-JP", "en-US"] : ["en-US"])
                    lines += (try? await recognizer.recognizeLines(in: data)) ?? []
                }
            }
        }
        let words = WordCandidateExtractor().candidates(from: lines, language: language)
        guard !words.isEmpty else {
            phase = .nothing(providers.isEmpty ? "Share some text or a picture with words in it."
                             : "No \(language == .japanese ? "Japanese" : "English") words found in that.")
            return
        }
        // A few shared words were chosen on purpose; a page is for picking from.
        phase = .words(words, preselected: sharedText && words.count <= 5)
    }

    private func text(from provider: NSItemProvider) async -> String? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) else { return nil }
        if let text = item as? String { return text }
        if let data = item as? Data { return String(data: data, encoding: .utf8) }
        if let text = item as? NSAttributedString { return text.string }
        return nil
    }

    private func data(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
