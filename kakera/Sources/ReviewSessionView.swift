import SwiftUI
import KakeraUI
import KakeraServices
import KakeraCore

/// One card's display content for a review session, projected from a `VocabularyEntry`.
struct ReviewCardData: Identifiable {
    /// Matches the backing entry's id so the store can apply ratings to it.
    let id: UUID
    let word: String
    let phonetic: String
    let explanation: String
    let explanationEn: String?
    let examples: [Example]
    let synonymGroups: [SynonymGroup]
    let collocations: [Collocation]
    var isLearned: Bool

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String,
        explanation: String,
        explanationEn: String? = nil,
        examples: [Example] = [],
        synonymGroups: [SynonymGroup] = [],
        collocations: [Collocation] = [],
        isLearned: Bool = false
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.explanation = explanation
        self.explanationEn = explanationEn
        self.examples = examples
        self.synonymGroups = synonymGroups
        self.collocations = collocations
        self.isLearned = isLearned
    }

    /// Projects a persisted entry into rich display data for the revealed card.
    init(entry: VocabularyEntry) {
        self.init(
            id: entry.id,
            word: entry.lemma,
            phonetic: entry.phonetic,
            explanation: entry.explanation,
            explanationEn: entry.explanationEn,
            examples: entry.examples,
            synonymGroups: entry.synonymGroups,
            collocations: entry.collocations,
            isLearned: entry.scheduling.state == .review
        )
    }
}

/// The core learning loop: flip a card, reveal the meaning, self-rate, advance.
/// Ratings flow to `ReviewStore`, which reschedules via FSRS and persists.
struct ReviewSessionView: View {
    let store: ReviewStore

    @Environment(\.modelContext) private var modelContext

    private enum Phase { case review, quiz }
    @State private var phase: Phase = .review
    @State private var quizStore: QuizStore?
    /// The words rated in this group, offered as a follow-up quiz on completion.
    @State private var reviewedIDs: [UUID] = []
    /// True while re-playing the just-completed cards ("Review again"): a pure practice
    /// pass that advances without rating, so it doesn't re-feed FSRS.
    @State private var isReplay = false

    @State private var index = 0
    @State private var revealed = false
    /// How far the card in hand has been swiped towards a rating (0…1); the next card
    /// rises to meet it.
    @State private var swipeProgress: Double = 0
    /// A rating chosen with a button: the card is thrown off in its direction (`fling`)
    /// and the rating is applied once it has left, as a swipe's would be.
    @State private var pendingRating: KakeraUI.ReviewRating?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDone = false
    @State private var showingStory = false
    /// The entry shown in the full-details sheet (opened from the revealed card).
    @State private var detailEntry: VocabularyEntry?

    /// Plays word pronunciations via Youdao's dictvoice audio.
    @State private var pronouncer = PronunciationPlayer()
    /// User setting: auto-play the pronunciation when each card appears.
    @AppStorage("autoPlayPronunciation") private var autoPlayPronunciation = true
    /// User setting: which accent to pronounce in.
    @AppStorage("pronunciationAccent") private var accentRaw = Accent.us.rawValue
    /// User setting: how many new words to introduce per session.
    @AppStorage("newWordsPerDay") private var newWordsPerDay = 10
    /// The language being studied; the header's menu switches it (which rebuilds the tabs).
    @AppStorage(AppSettings.studyLanguageKey) private var studyLanguageRaw = LanguageDomain.english.rawValue

    private var accent: Accent { Accent(rawValue: accentRaw) ?? .us }
    private var language: LanguageDomain { LanguageDomain(rawValue: studyLanguageRaw) ?? .english }

    private var cards: [ReviewCardData] { store.cards }

    var body: some View {
        ZStack {
            KakeraColor.washi.ignoresSafeArea()

            if phase == .quiz, let quizStore {
                QuizSessionView(store: quizStore, onClose: endQuiz)
            } else {
                reviewContent
            }
        }
        .kakeraToast("Nice — deck complete", isPresented: $showDone)
        .sheet(isPresented: $showingStory) {
            StoryView(store: StoryStore(context: modelContext))
        }
        .sheet(isPresented: Binding(get: { detailEntry != nil }, set: { if !$0 { detailEntry = nil } })) {
            if let detailEntry {
                NavigationStack { WordDetailView(entry: detailEntry) }
            }
        }
    }

    /// The revealed side of the card: meaning (bilingual), every example, similar words,
    /// and collocations — scrollable — plus a link to the full detail page. Its text is
    /// `RubyText`, so a long press selects it for Copy, Look Up, Translate.
    @ViewBuilder
    private func cardBack(_ card: ReviewCardData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KakeraSpacing.m) {
                VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
                    RubyText(card.word, size: 23, weight: .semibold, design: .serif)
                    if !card.phonetic.isEmpty {
                        PhoneticText(card.phonetic, size: 13)
                            .foregroundStyle(KakeraColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RubyText(card.explanation, size: 20, design: .serif)
                if let en = card.explanationEn, !en.isEmpty {
                    RubyText(en, size: 15, color: KakeraColor.inkSecondary)
                }

                if !card.examples.isEmpty {
                    backDivider
                    backLabel("Examples")
                    ForEach(Array(card.examples.enumerated()), id: \.offset) { _, ex in
                        VStack(alignment: .leading, spacing: 2) {
                            RubyText(ex.sentence, size: 16)
                            if !ex.translation.isEmpty {
                                RubyText(ex.translation, size: 14, color: KakeraColor.inkSecondary)
                            }
                        }
                    }
                }

                if !card.synonymGroups.isEmpty {
                    backDivider
                    backLabel("Similar words")
                    ForEach(Array(card.synonymGroups.enumerated()), id: \.offset) { _, group in
                        RubyText("\(group.sense) · \(group.words.joined(separator: ", "))", size: 15)
                    }
                }

                if !card.collocations.isEmpty {
                    backDivider
                    backLabel("Collocations")
                    ForEach(Array(card.collocations.enumerated()), id: \.offset) { _, c in
                        // Bottom-aligned: a phrase with furigana is taller than its gloss.
                        HStack(alignment: .bottom, spacing: KakeraSpacing.s) {
                            RubyText(c.phrase, size: 15, weight: .semibold)
                                .fixedSize()
                            RubyText(c.meaning, size: 13, color: KakeraColor.inkSecondary)
                        }
                    }
                }

                Button { detailEntry = store.entry(for: card) } label: {
                    HStack(spacing: 4) {
                        Text("Full details")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .font(KakeraFont.body(14, weight: .semibold))
                    .foregroundStyle(KakeraColor.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, KakeraSpacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Room at the sides inside the scroll view, which clips: furigana may hang a
            // little past the text (see RubyText).
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, -8)
        // iOS 26 blurs content scrolling under a scroll view's edge — meant for bars, not a
        // card, and inside the card's 3D turn the blur spreads over most of the back.
        .withoutScrollEdgeEffect()
    }

    private func backLabel(_ text: String) -> some View {
        Text(text)
            .font(KakeraFont.body(11, weight: .semibold))
            .foregroundStyle(KakeraColor.accent)
            .textCase(.uppercase)
            .tracking(1.5)
    }

    private var backDivider: some View {
        Rectangle().fill(KakeraColor.hairline).frame(height: 1).padding(.vertical, 2)
    }

    private var reviewContent: some View {
        GeometryReader { proxy in
            // A short screen (an iPhone Duo folded) gives its margins to the card.
            let tight = proxy.size.height < Self.tightHeight
            VStack(spacing: tight ? KakeraSpacing.m : KakeraSpacing.l) {
                header
                SessionProgressBar(progress: cards.isEmpty ? 0 : Double(index) / Double(cards.count))

                if index < cards.count {
                    let card = cards[index]
                    // The card and its buttons are one column, centred and no wider than a card reads well: on a wide
                    // screen (a Duo unfolded, on its side) they don't stretch across it.
                    VStack(spacing: tight ? KakeraSpacing.m : KakeraSpacing.l) {
                        // The card gives way first on a short screen, so the buttons stay in view.
                        cardStack(card)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                        controls(for: card)
                            .padding(.bottom, tight ? 0 : KakeraSpacing.s)
                    }
                    .frame(maxWidth: Self.columnWidth)
                    .frame(maxWidth: .infinity)
                } else {
                    completed
                }
            }
            .padding(.horizontal, KakeraSpacing.l)
            .padding(.vertical, tight ? KakeraSpacing.s : KakeraSpacing.l)
        }
    }

    /// Below this height the review screen tightens its margins (the Duo folded is about 640 pt).
    private static let tightHeight: CGFloat = 720
    /// The widest the card and its buttons get.
    private static let columnWidth: CGFloat = 560

    /// The card in hand, and the next one rising behind it as this one leaves.
    private func cardStack(_ card: ReviewCardData) -> some View {
        ZStack {
            // The next card rises into place only as this one is swiped or thrown
            // away. At rest it is not there at all: the card in hand turns edge-on
            // as it flips, and nothing may show through behind it.
            if index + 1 < cards.count {
                let next = cards[index + 1]
                FlipCardFace(word: next.word, phonetic: next.phonetic)
                    .scaleEffect(0.94 + 0.06 * swipeProgress)
                    .offset(y: 16 * (1 - swipeProgress))
                    .opacity(swipeProgress)
            }
            FlipCard(
                word: card.word,
                phonetic: card.phonetic,
                isLearned: card.isLearned,
                autoPlays: autoPlayPronunciation,
                isRevealed: $revealed,
                onSpeak: { pronouncer.say(card.word, phonetic: card.phonetic, language: language, accent: accent) },
                // Right is Good, left is Again; Hard and Easy stay on the buttons.
                // A swipe rates Good (right) or Again (left); a thrown card carries
                // the rating its button chose.
                onSwipe: { direction in
                    let rating = pendingRating ?? (direction == .right ? .good : .again)
                    pendingRating = nil
                    rate(card, rating, swiped: !reduceMotion)
                },
                onSwipeProgress: { swipeProgress = $0 },
                fling: pendingRating.map { $0 == .again || $0 == .hard ? .left : .right }
            ) {
                cardBack(card)
            }
            .id(card.id)   // a fresh card (and turn state) per word
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
                Text("Kakera")
                    .font(KakeraFont.display(34, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(KakeraColor.sumi)
                languageMenu
            }
            Spacer()
            Button { showingStory = true } label: {
                Image(systemName: "book.pages")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KakeraColor.accent)
            }
            .buttonStyle(KakeraPressStyle())
            .accessibilityLabel("Daily story")
            .padding(.trailing, KakeraSpacing.s)
            Text("\(min(index + 1, cards.count)) / \(cards.count)")
                .font(KakeraFont.phonetic(16))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
    }

    /// Which deck is being studied, and the switch between them.
    private var languageMenu: some View {
        Menu {
            Picker("Studying", selection: $studyLanguageRaw) {
                ForEach(LanguageDomain.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("欠片 · \(language.displayName)")
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(KakeraFont.body(14, weight: .medium))
            .foregroundStyle(KakeraColor.inkSecondary)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Studying \(language.displayName)")
        .accessibilityHint("Switches to another language's deck")
    }

    @ViewBuilder
    private func controls(for card: ReviewCardData) -> some View {
        if revealed {
            RatingBar(interval: { store.previewInterval(for: card, rating: $0.core) }) { rating in
                // Again and Hard throw the card left, Good and Easy right — the same way
                // the swipes go — and the next card rises as it leaves.
                guard pendingRating == nil else { return }
                pendingRating = rating
            }
            .allowsHitTesting(pendingRating == nil)
        } else {
            KakeraPrimaryButton("Show answer") {
                withAnimation(KakeraMotion.flip) { revealed = true }
            }
        }
    }

    /// Records a rating (from a button or a swipe) and moves to the next card.
    private func rate(_ card: ReviewCardData, _ rating: KakeraUI.ReviewRating, swiped: Bool = false) {
        // On a replay pass, just advance — don't re-rate or re-feed FSRS.
        if !isReplay {
            store.rate(card, rating.core)
            // A re-drilled (lapsed) card can be rated more than once; count it once.
            if !reviewedIDs.contains(card.id) { reviewedIDs.append(card.id) }
        }
        advance(swiped: swiped)
    }

    private var completed: some View {
        VStack(spacing: KakeraSpacing.m) {
            Spacer()
            Text("Done")
                .font(KakeraFont.display(48, weight: .bold))
                .foregroundStyle(KakeraColor.accent)
            if reviewedIDs.isEmpty {
                // Nothing was due, so there is nothing to replay — no button here.
                Text("All caught up for now.")
                    .font(KakeraFont.body(17, weight: .medium))
                    .foregroundStyle(KakeraColor.sumi)
            } else {
                Text("Reviewed \(reviewedIDs.count) — lock it in with a quick quiz.")
                    .font(KakeraFont.body(17, weight: .medium))
                    .foregroundStyle(KakeraColor.sumi)
                    .multilineTextAlignment(.center)
                KakeraPrimaryButton("Start quiz") { startQuiz() }
                    .padding(.top, KakeraSpacing.s)
                    .frame(maxWidth: 240)
                Button("Review again") { replay() }
                    .font(KakeraFont.body(15, weight: .medium))
                    .foregroundStyle(KakeraColor.inkSecondary)
                    .padding(.top, KakeraSpacing.xs)
            }
            Spacer()
        }
        .padding(.horizontal, KakeraSpacing.l)
    }

    /// Moves to the next card. After a swipe the card in hand has already left and the
    /// next one has risen into its place, so the swap is instant: animating it faded the
    /// new card in over the one after it, which flashed through for a few frames.
    private func advance(swiped: Bool = false) {
        var transaction = Transaction(animation: swiped ? nil : KakeraMotion.standard)
        transaction.disablesAnimations = swiped
        withTransaction(transaction) {
            revealed = false
            swipeProgress = 0
            index += 1
            if index >= cards.count {
                showDone = true
                KakeraHaptics.success()
            }
        }
    }

    /// Re-plays the just-completed cards for another practice pass over the same
    /// snapshot. Keeps `reviewedIDs` so a quiz is still offered; `isReplay` makes the
    /// pass advance without re-rating.
    private func replay() {
        isReplay = true
        withAnimation(KakeraMotion.standard) {
            index = 0
            revealed = false
        }
    }

    /// Loads a fresh due session from the store (used after a follow-up quiz), resetting
    /// replay state so ratings feed FSRS again.
    private func loadFreshSession() {
        store.load(newLimit: newWordsPerDay)
        reviewedIDs = []
        isReplay = false
        withAnimation(KakeraMotion.standard) {
            index = 0
            revealed = false
        }
    }

    /// Chains a quiz over the words just reviewed. Falls back to a replay pass if none
    /// of them can form a question (e.g. missing meanings).
    private func startQuiz() {
        let quiz = QuizStore(context: modelContext)
        quiz.load(entryIDs: reviewedIDs)
        guard !quiz.questions.isEmpty else { replay(); return }
        quizStore = quiz
        withAnimation(KakeraMotion.standard) { phase = .quiz }
    }

    private func endQuiz() {
        quizStore = nil
        withAnimation(KakeraMotion.standard) { phase = .review }
        loadFreshSession()
    }
}

/// Maps the UI's rating (KakeraUI) to the domain rating (KakeraCore). The two enums are
/// deliberately separate so the design system carries no domain dependency.
private extension KakeraUI.ReviewRating {
    var core: KakeraCore.ReviewRating {
        switch self {
        case .again: return .again
        case .hard: return .hard
        case .good: return .good
        case .easy: return .easy
        }
    }
}

private extension View {
    /// Turns off the iOS 26 scroll edge effect; earlier systems have none.
    @ViewBuilder
    func withoutScrollEdgeEffect() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }
}
