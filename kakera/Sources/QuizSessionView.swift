import SwiftUI
import KakeraUI
import KakeraServices

/// A quiz session over the just-reviewed words. Questions vary by type: tap a choice, or
/// type the answer (fill-in-blank / listening). A wrong answer re-grades the word as
/// "again" via `QuizStore` (the double-check); a correct answer is a no-op.
struct QuizSessionView: View {
    let store: QuizStore
    /// When set (the quiz was chained after a review), completion offers "Back to
    /// review" and calls this instead of restarting.
    var onClose: (() -> Void)? = nil

    @State private var index = 0
    @State private var selected: Int?          // chosen option (choice mode)
    @State private var textInput = ""          // typed answer (text mode)
    @State private var responded = false       // this question has been answered
    @State private var wasCorrect = false
    @State private var correctCount = 0
    @State private var showDone = false
    /// Bumped on each wrong answer: the answer area shakes as the error haptic fires.
    @State private var misses = 0

    @State private var pronouncer = PronunciationPlayer()
    @AppStorage("pronunciationAccent") private var accentRaw = Accent.us.rawValue
    private var accent: Accent { Accent(rawValue: accentRaw) ?? .us }
    private let language = AppSettings.studyLanguage

    /// Right answers read in the accent, wrong ones in the danger red.
    private let pine = KakeraColor.accent
    private let miss = KakeraColor.danger
    private var questions: [QuizQuestion] { store.questions }

    var body: some View {
        ZStack {
            KakeraColor.washi.ignoresSafeArea()

            VStack(spacing: KakeraSpacing.l) {
                header
                SessionProgressBar(progress: questions.isEmpty ? 0 : Double(index) / Double(questions.count))

                if index < questions.count {
                    let question = questions[index]
                    ScrollView {
                        VStack(spacing: KakeraSpacing.l) {
                            promptCard(question)
                            Group {
                                if question.isTextEntry {
                                    textEntry(question)
                                } else {
                                    optionsList(question)
                                }
                            }
                            .kakeraShake(trigger: misses)
                        }
                        .id(question.id)   // reset per question
                    }
                    Spacer(minLength: 0)
                } else {
                    completed
                }
            }
            .padding(KakeraSpacing.l)
        }
        .kakeraToast("Quiz complete", isPresented: $showDone)
        .task(id: index) {
            // Auto-play the pronunciation for a listening question.
            guard index < questions.count, questions[index].playsAudio else { return }
            pronouncer.say(questions[index].word, phonetic: questions[index].phonetic, language: language, accent: accent)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
                Text("Kakera")
                    .font(KakeraFont.display(34, weight: .bold))
                    .foregroundStyle(KakeraColor.sumi)
                Text("欠片 · quiz")
                    .font(KakeraFont.body(14, weight: .medium))
                    .foregroundStyle(KakeraColor.inkSecondary)
            }
            Spacer()
            Text("\(min(index + 1, questions.count)) / \(questions.count)")
                .font(KakeraFont.phonetic(16))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
    }

    // MARK: Prompt

    private func promptCard(_ question: QuizQuestion) -> some View {
        VStack(spacing: KakeraSpacing.s) {
            if question.hidesWord && !responded {
                if question.playsAudio {
                    Button { pronouncer.say(question.word, phonetic: question.phonetic, language: language, accent: accent) } label: {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(KakeraColor.accent)
                    }
                    .buttonStyle(KakeraPressStyle())
                    Text(language == .japanese ? "Type the reading you hear" : "Spell what you hear")
                        .font(KakeraFont.body(14, weight: .medium))
                        .foregroundStyle(KakeraColor.inkSecondary)
                } else {
                    Text("? ? ?")
                        .font(KakeraFont.display(34, weight: .bold))
                        .foregroundStyle(KakeraColor.inkSecondary.opacity(0.35))
                }
            } else {
                Text(question.word)
                    .font(KakeraFont.display(38, weight: .bold))
                    .foregroundStyle(KakeraColor.sumi)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: KakeraSpacing.s) {
                    if !question.phonetic.isEmpty {
                        PhoneticText(question.phonetic, size: 14)
                            .foregroundStyle(KakeraColor.inkSecondary)
                    }
                    Button {
                        KakeraHaptics.impact(.light)
                        pronouncer.say(question.word, phonetic: question.phonetic, language: language, accent: accent)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KakeraColor.accent)
                    }
                    .buttonStyle(KakeraPressStyle())
                }
            }

            if !question.question.isEmpty {
                RubyText(question.question, size: 16, alignment: .center)
                    .padding(.top, KakeraSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KakeraSpacing.xl)
        .padding(.horizontal, KakeraSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(KakeraColor.cardFace)
                .shadow(color: KakeraColor.shadow, radius: 14, x: 0, y: 8)
        )
    }

    // MARK: Choice mode

    private func optionsList(_ question: QuizQuestion) -> some View {
        VStack(spacing: KakeraSpacing.s) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { pair in
                optionButton(question, index: pair.offset, text: pair.element)
            }
        }
    }

    private func optionButton(_ question: QuizQuestion, index optionIndex: Int, text: String) -> some View {
        let isCorrect = question.isCorrect(choiceIndex: optionIndex)
        let isChosen = optionIndex == selected

        let tint: Color = !responded ? KakeraColor.hairline
            : isCorrect ? pine
            : isChosen ? miss
            : KakeraColor.hairline
        let fill: Color = responded && isCorrect ? pine.opacity(0.12)
            : responded && isChosen ? miss.opacity(0.10)
            : KakeraColor.cardFace

        return Button {
            choose(question, optionIndex)
        } label: {
            HStack(spacing: KakeraSpacing.s) {
                Text(text)
                    .font(KakeraFont.body(16, weight: .medium))
                    .foregroundStyle(KakeraColor.sumi)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: KakeraSpacing.s)
                if responded && isCorrect {
                    Image(systemName: "checkmark").foregroundStyle(pine)
                } else if responded && isChosen {
                    Image(systemName: "xmark").foregroundStyle(miss)
                }
            }
            .padding(.horizontal, KakeraSpacing.m)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1.5)
            )
            .opacity(responded && !isCorrect && !isChosen ? 0.5 : 1)
        }
        .buttonStyle(KakeraPressStyle())
        .disabled(responded)
    }

    // MARK: Text mode

    private func textEntry(_ question: QuizQuestion) -> some View {
        VStack(spacing: KakeraSpacing.m) {
            TextField(language == .japanese ? "Type it in kana" : "Type the word", text: $textInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(KakeraFont.body(18))
                .multilineTextAlignment(.center)
                .padding(.vertical, KakeraSpacing.m)
                .padding(.horizontal, KakeraSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(KakeraColor.cardFace)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(textFieldTint, lineWidth: 1.5))
                )
                .disabled(responded)
                .onSubmit { submitText(question) }

            if responded {
                HStack(spacing: KakeraSpacing.s) {
                    Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(wasCorrect ? pine : miss)
                    Text(wasCorrect ? "Correct" : "Answer: \(question.answers.first ?? question.word)")
                        .font(KakeraFont.body(15, weight: .medium))
                        .foregroundStyle(KakeraColor.sumi)
                }
            } else {
                KakeraPrimaryButton("Check") { submitText(question) }
                    .frame(maxWidth: 200)
                    .opacity(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var textFieldTint: Color {
        guard responded else { return KakeraColor.hairline }
        return wasCorrect ? pine : miss
    }

    // MARK: Completion

    private var completed: some View {
        VStack(spacing: KakeraSpacing.m) {
            Spacer()
            Text("Done")
                .font(KakeraFont.display(48, weight: .bold))
                .foregroundStyle(KakeraColor.accent)
            Text(questions.isEmpty
                 ? "Nothing to quiz right now."
                 : "\(correctCount) of \(questions.count) correct.")
                .font(KakeraFont.body(17, weight: .medium))
                .foregroundStyle(KakeraColor.sumi)
            if let onClose {
                KakeraPrimaryButton("Back to review", action: onClose)
                    .padding(.top, KakeraSpacing.m)
                    .frame(maxWidth: 220)
            } else if !questions.isEmpty {
                KakeraPrimaryButton("Quiz again") { restart() }
                    .padding(.top, KakeraSpacing.m)
                    .frame(maxWidth: 220)
            }
            Spacer()
        }
    }

    // MARK: Actions

    private func choose(_ question: QuizQuestion, _ optionIndex: Int) {
        guard !responded else { return }
        withAnimation(KakeraMotion.snappy) { selected = optionIndex }
        grade(question, .choice(optionIndex))
    }

    private func submitText(_ question: QuizQuestion) {
        guard !responded, !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        grade(question, .text(textInput))
    }

    private func grade(_ question: QuizQuestion, _ response: QuizResponse) {
        responded = true
        let correct = store.submit(question, response)
        wasCorrect = correct
        if correct {
            correctCount += 1
            KakeraHaptics.impact(.light)
        } else {
            KakeraHaptics.impact(.rigid)
            misses += 1
        }
        Task { @MainActor in
            // Linger a little longer on a miss so the answer registers.
            try? await Task.sleep(for: .seconds(correct ? 0.9 : 1.6))
            advance()
        }
    }

    private func advance() {
        withAnimation(KakeraMotion.standard) {
            selected = nil
            textInput = ""
            responded = false
            wasCorrect = false
            index += 1
            if index >= questions.count {
                showDone = true
                KakeraHaptics.success()
            }
        }
    }

    private func restart() {
        store.load()
        withAnimation(KakeraMotion.standard) {
            index = 0
            selected = nil
            textInput = ""
            responded = false
            correctCount = 0
        }
    }
}
