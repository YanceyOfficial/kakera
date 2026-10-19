import SwiftUI
import SwiftData
import KakeraCore
import KakeraUI

/// Lists every entry of the language being studied and is the entry point for authoring new words.
/// Reads/writes through `VocabularyRepository` built from the shared context.
struct WordsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toast

    @State private var entries: [VocabularyEntry] = []
    @State private var showingAdd = false
    @State private var searchText = ""
    @State private var selectedTag: String?

    private var repository: VocabularyRepository { VocabularyRepository(context: modelContext) }

    /// All distinct tags across the deck, for the filter bar.
    private var allTags: [String] { Array(Set(entries.flatMap(\.tags))).sorted() }

    /// Entries filtered by the active tag (if any) and the search field (word name only,
    /// so "th" finds "thick", not every entry whose meaning contains "th"; a Japanese
    /// word's kana reading counts as its name).
    private var filteredEntries: [VocabularyEntry] {
        var result = entries
        if let selectedTag { result = result.filter { $0.tags.contains(selectedTag) } }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        // A Japanese word is found by its reading too (なつ → 懐かしい).
        if !query.isEmpty {
            result = result.filter {
                $0.lemma.lowercased().contains(query) || ($0.language == .japanese && $0.phonetic.contains(query))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KakeraColor.washi.ignoresSafeArea()
                VStack(alignment: .leading, spacing: KakeraSpacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Words")
                            .font(KakeraFont.display(34, weight: .bold))
                            .foregroundStyle(KakeraColor.sumi)
                        Spacer()
                        Button { showingAdd = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(KakeraColor.vermilion)
                        }
                        .buttonStyle(KakeraPressStyle())
                    }
                    .padding(.horizontal, KakeraSpacing.l)

                    searchField
                        .padding(.horizontal, KakeraSpacing.l)

                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KakeraSpacing.s) {
                                ForEach(allTags, id: \.self) { tagChip($0) }
                            }
                            .padding(.horizontal, KakeraSpacing.l)
                        }
                    }

                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, KakeraSpacing.l)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAdd, onDismiss: reload) {
                AddWordsView()
            }
        }
        .task { reload() }
    }

    private func tagChip(_ tag: String) -> some View {
        let selected = selectedTag == tag
        return Button {
            selectedTag = selected ? nil : tag
        } label: {
            Text(tag)
                .font(KakeraFont.body(14, weight: .medium))
                .foregroundStyle(selected ? KakeraColor.cardFace : KakeraColor.sumi)
                .padding(.horizontal, KakeraSpacing.m)
                .padding(.vertical, KakeraSpacing.xs)
                .background(Capsule().fill(selected ? KakeraColor.vermilion : KakeraColor.cardFace))
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: KakeraSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(KakeraColor.inkSecondary)
            TextField("Search words", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KakeraColor.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KakeraSpacing.m)
        .padding(.vertical, KakeraSpacing.s)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(KakeraColor.cardFace))
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label("No words yet", systemImage: "text.book.closed")
            } description: {
                Text("Tap + to add words to study.")
            }
        } else if filteredEntries.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                ForEach(filteredEntries) { entry in
                    NavigationLink { WordDetailView(entry: entry) } label: { row(entry) }
                        .listRowBackground(KakeraColor.cardFace)
                }
                .onDelete(perform: delete)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
            Text(entry.lemma)
                .font(KakeraFont.display(19, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)
            if !entry.phonetic.isEmpty {
                PhoneticText(entry.phonetic, size: 12)
                    .foregroundStyle(KakeraColor.inkSecondary)
                    .lineLimit(1)
            }
            if !entry.explanation.isEmpty {
                Text(entry.explanation)
                    .font(KakeraFont.body(14, weight: .regular))
                    .foregroundStyle(KakeraColor.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func reload() {
        entries = (try? repository.entries(for: AppSettings.studyLanguage)) ?? []
        if let tag = selectedTag, !entries.contains(where: { $0.tags.contains(tag) }) {
            selectedTag = nil   // the tag no longer exists — drop the filter
        }
    }

    private func delete(at offsets: IndexSet) {
        let visible = filteredEntries
        let removed = offsets.map { visible[$0] }
        for entry in removed {
            try? repository.delete(entry)
        }
        reload()
        if let first = removed.first {
            toast.show(removed.count == 1 ? "Deleted ‘\(first.lemma)’" : "Deleted \(removed.count) words")
        }
    }
}
