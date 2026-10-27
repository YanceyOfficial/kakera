import SwiftUI
import SwiftData
import PhotosUI
import KakeraCore
import KakeraAI
import KakeraUI
import KakeraServices

/// Authoring sheet: type or paste words (one per line) and AI generates full cards, into
/// the deck of the language being studied. A single word is just a one-line entry.
///
/// Once "Generate" is tapped the field gives way to the words themselves, each with its
/// state: waiting, being written, in the deck (with its gloss), not recognized (with the
/// model's suggestions to pick from), or failed (with the reason and a retry). Cards land
/// one by one, so a batch of twenty isn't a spinner for ten minutes; when every word is
/// in, the sheet closes on its own.
///
/// Words can also come from a picture — a photo from the library or the camera, read on
/// the device by Vision — offered as chips to pick from (`WordPickerSheet`), or arrive
/// already typed in from the share extension (`WordInbox`, `init(words:)`).
struct AddWordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast

    @State private var pasted: String
    /// Created when generation starts; the sheet shows its items from then on.
    @State private var store: AddWordsStore?
    @FocusState private var fieldFocused: Bool

    @State private var showingPhotos = false
    @State private var showingCamera = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isReading = false
    /// The camera's photo, read once the camera has left the screen.
    @State private var cameraPhoto: Data?
    /// Why the last scan offered nothing, under the scan row until the next one.
    @State private var scanNote: String?
    /// Words read from a picture, offered to pick from.
    @State private var scanned: ScannedWords?

    /// - Parameter words: words to start with, one per line (the share extension's inbox).
    init(words: [String] = []) {
        _pasted = State(initialValue: words.joined(separator: "\n"))
    }

    /// One lemma per non-empty line.
    private var lemmas: [String] { PastedWordsParser.lemmas(from: pasted) }

    private var hasKey: Bool { AIConfigStore.hasKey }
    private var canGenerate: Bool { hasKey && !lemmas.isEmpty }
    private var providerName: String { AIConfigStore.currentKind() == .openai ? "OpenAI" : "Claude" }

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    progress(store)
                } else {
                    composer
                }
            }
            .navigationTitle(store == nil ? "Add words" : "Adding words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let store, store.isGenerating {
                        Button("Stop") { store.stop() }
                    } else if store == nil {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let store {
                        Button("Done") { dismiss() }
                            .disabled(!store.isSettled)
                    } else {
                        Button("Generate") { generate() }.disabled(!canGenerate)
                    }
                }
            }
            .onChange(of: store?.isSettled ?? false) { _, settled in
                if settled { finish() }
            }
        }
        .tint(KakeraColor.accent)
        // A swipe down mustn't silently drop what's in flight: Stop is explicit.
        .interactiveDismissDisabled(store?.isGenerating == true)
    }

    // MARK: Composing

    private var composer: some View {
        Form {
            Section {
                TextField(AppSettings.studyLanguage == .japanese ? "One word per line — 懐かしい" : "One word per line", text: $pasted, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 160, alignment: .topLeading)
                    .focused($fieldFocused)
                scanRow
                if let scanNote {
                    Label(scanNote, systemImage: "exclamationmark.triangle")
                        .font(KakeraFont.body(14))
                        .foregroundStyle(KakeraColor.danger)
                }
            } header: {
                Text("Words")
            } footer: {
                if !hasKey {
                    Text("Add an API key in Settings to generate words.")
                } else {
                    Text("\(providerName) fills in \(AppSettings.studyLanguage == .japanese ? "readings" : "phonetics"), meanings, and examples, one word at a time. \(lemmas.count) word\(lemmas.count == 1 ? "" : "s").")
                }
            }
        }
        .task {
            // Focus the field (and raise the keyboard) as the sheet settles.
            try? await Task.sleep(nanoseconds: 350_000_000)
            fieldFocused = true
        }
        .photosPicker(isPresented: $showingPhotos, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await read(data) }
            }
        }
        // The photo is read only once the camera is off the screen: a sheet presented while the
        // camera is still leaving is dropped by UIKit, and the words would never appear.
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            guard let data = cameraPhoto else { return }
            cameraPhoto = nil
            Task { await read(data) }
        }) {
            #if DEBUG
            if DemoCamera.isRequested {
                DemoCameraView { data in cameraPhoto = data }
            } else {
                CameraPicker { data in cameraPhoto = data }.ignoresSafeArea()
            }
            #else
            CameraPicker { data in cameraPhoto = data }.ignoresSafeArea()
            #endif
        }
        .overlay {
            if isReading {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("Reading the picture…")
                        .padding(KakeraSpacing.l)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isReading)
        .sheet(item: $scanned) { found in
            WordPickerSheet(
                words: found.words, preselected: false,
                footnote: "Read on this iPhone; nothing is sent. The picked words join the list to generate."
            ) {
                scanned = nil
            } onAdd: { picked in
                scanned = nil
                let existing = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                pasted = ((existing.isEmpty ? [] : [existing]) + picked).joined(separator: "\n")
            }
        }
    }

    /// The row under the text field: scan the words out of a photo.
    private var scanRow: some View {
        Menu {
            Button { showingPhotos = true } label: { Label("Choose photo", systemImage: "photo.on.rectangle") }
            if CameraPicker.isAvailable {
                Button { showingCamera = true } label: { Label("Take photo", systemImage: "camera") }
            }
        } label: {
            Label("Scan words from a photo", systemImage: "text.viewfinder")
        }
        .disabled(isReading)
    }

    /// Recognizes the text in a picture and offers its words. What goes wrong is said under the
    /// scan row, where it can be seen: a toast would show behind this sheet.
    private func read(_ data: Data) async {
        isReading = true
        scanNote = nil
        defer { isReading = false }
        let language: CandidateLanguage = AppSettings.studyLanguage == .japanese ? .japanese : .english
        let recognizer = VisionTextRecognizer(languages: language == .japanese ? ["ja-JP", "en-US"] : ["en-US"])
        let lines: [String]
        do {
            lines = try await recognizer.recognizeLines(in: data)
        } catch {
            scanNote = "Couldn't read that picture: \(error.localizedDescription)"
            AppLog.shared.error("Scan failed: \(error.localizedDescription)", category: "scan")
            return
        }
        let words = WordCandidateExtractor().candidates(from: lines, language: language)
        guard !words.isEmpty else {
            scanNote = lines.isEmpty
                ? "No text found in that picture. Try a closer, sharper shot."
                : "No \(language == .japanese ? "Japanese" : "English") words in that picture."
            AppLog.shared.info("Scan read \(lines.count) lines and no words", category: "scan")
            return
        }
        scanned = ScannedWords(words: words)
    }

    /// The words read from one picture (an `Identifiable` for the sheet).
    private struct ScannedWords: Identifiable {
        let id = UUID()
        let words: [String]
    }

    private func generate() {
        let words = lemmas
        guard !words.isEmpty else { return }
        let store = AddWordsStore(repository: VocabularyRepository(context: modelContext), language: AppSettings.studyLanguage)
        self.store = store
        store.start(words: words)
    }

    /// Everything settled: close on the words that are in, or stay for the ones that need the learner.
    private func finish() {
        guard let store, !store.needsAttention else { return }
        KakeraHaptics.success()
        let added = store.addedCount
        toast.show(added == 0 ? "Already in your deck" : "Added \(added) word\(added == 1 ? "" : "s")")
        dismiss()
    }

    // MARK: Progress

    private func progress(_ store: AddWordsStore) -> some View {
        List {
            Section {
                ForEach(store.items) { item in
                    row(item, store: store)
                }
            } header: {
                Text(headline(store))
            } footer: {
                footer(store)
            }
            .listRowBackground(KakeraColor.cardFace)
        }
        .scrollContentBackground(.hidden)
        .background(KakeraColor.washi)
        .animation(.default, value: store.items)
    }

    private func headline(_ store: AddWordsStore) -> String {
        let total = store.items.count
        if store.isGenerating {
            return "\(providerName) is writing · \(store.addedCount) of \(total) in"
        }
        return "\(store.addedCount) of \(total) in your deck"
    }

    @ViewBuilder
    private func footer(_ store: AddWordsStore) -> some View {
        if let error = store.setupError {
            Text(error).foregroundStyle(KakeraColor.danger)
        } else if store.isGenerating {
            Text("Each card lands in your deck as soon as it's written — a word takes \(providerName) a minute or two. Stop keeps what's already in.")
        } else if store.needsAttention {
            Text("Pick a suggestion, try again, or remove a word to finish.")
        }
    }

    private func row(_ item: AddWordsStore.Item, store: AddWordsStore) -> some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
            // The mark sits in a fixed box, centred on the word: the spinner and the symbols
            // take the same room, so every row has the same shape whatever its state.
            HStack(alignment: .center, spacing: KakeraSpacing.s) {
                Text(item.word)
                    .font(KakeraFont.display(17, weight: .semibold))
                    .foregroundStyle(KakeraColor.sumi)
                Spacer(minLength: KakeraSpacing.s)
                statusMark(item.status)
                    .frame(width: 22, height: 22)
            }
            // One line of detail in one voice for every state; the mark carries the colour.
            Text(detail(item.status))
                .font(KakeraFont.body(13))
                .foregroundStyle(KakeraColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            switch item.status {
            case .unrecognized(_, let suggestions):
                if !suggestions.isEmpty {
                    FlowLayout(spacing: 6) {
                        Text("Did you mean")
                            .font(KakeraFont.body(13))
                            .foregroundStyle(KakeraColor.inkSecondary)
                            .padding(.vertical, 4)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button { store.replace(item.id, with: suggestion) } label: {
                                Text(suggestion)
                                    .font(KakeraFont.body(14, weight: .medium))
                                    .foregroundStyle(KakeraColor.accent)
                                    .padding(.horizontal, KakeraSpacing.s)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(KakeraColor.accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                actions(item, store: store, retry: false)
            case .failed:
                actions(item, store: store, retry: true)
            case .queued, .generating, .added, .alreadyInDeck:
                EmptyView()
            }
        }
        .padding(.vertical, 2)
    }

    private func detail(_ status: AddWordsStore.Status) -> String {
        switch status {
        case .queued: "Waiting"
        case .generating: "Writing the card…"
        case .added(let gloss): gloss
        case .alreadyInDeck: "Already in your deck"
        case .unrecognized(let reason, _): "Not recognized — \(reason)"
        case .failed(let message): message
        }
    }

    /// Try again (after a failure) and Remove, in one row.
    private func actions(_ item: AddWordsStore.Item, store: AddWordsStore, retry: Bool) -> some View {
        HStack(spacing: KakeraSpacing.m) {
            if retry {
                Button("Try again") { store.retry(item.id) }
            }
            Button("Remove", role: .destructive) { store.remove(item.id) }
        }
        .font(KakeraFont.body(14, weight: .semibold))
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func statusMark(_ status: AddWordsStore.Status) -> some View {
        switch status {
        case .queued:
            Image(systemName: "circle.dotted")
                .foregroundStyle(KakeraColor.inkSecondary)
        case .generating:
            ProgressView().controlSize(.small)
        case .added:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(KakeraColor.accent)
        case .alreadyInDeck:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(KakeraColor.inkSecondary)
        case .unrecognized:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(KakeraColor.inkSecondary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(KakeraColor.danger)
        }
    }
}
