import SwiftUI
import KakeraAI
import KakeraUI

/// First-run setup: a light welcome that gets the API key + daily goal in place, so a
/// real user isn't dropped cold into an app that can't generate words yet.
struct OnboardingView: View {
    @Binding var hasOnboarded: Bool

    @AppStorage("aiProvider") private var aiProviderRaw = LLMProviderKind.claude.rawValue
    @AppStorage("newWordsPerDay") private var newWordsPerDay = 10
    @State private var apiKey = ""

    private var aiKind: LLMProviderKind { LLMProviderKind(rawValue: aiProviderRaw) ?? .claude }
    private let newWordOptions = [5, 10, 15, 20, 30]

    var body: some View {
        ZStack {
            KakeraColor.washi.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: KakeraSpacing.xl) {
                    brand
                    bullets
                    aiSetup
                    goal
                    KakeraPrimaryButton("Start learning") { finish() }
                }
                .padding(KakeraSpacing.l)
                .padding(.top, KakeraSpacing.l)
            }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.s) {
            KakeraMark(height: 46)
                .padding(.bottom, KakeraSpacing.xs)
            Text("Welcome to Kakera")
                .font(KakeraFont.display(30, weight: .bold))
                .foregroundStyle(KakeraColor.sumi)
            Text("Memorize hard vocabulary with AI-built cards and scientific spaced repetition.")
                .font(KakeraFont.body(16))
                .foregroundStyle(KakeraColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.m) {
            bullet("sparkles", "AI-enriched cards",
                   "Meanings, examples, mnemonics, and quizzes — generated for each word.")
            bullet("brain.head.profile", "Scientific memory",
                   "FSRS schedules every word right before you'd forget it.")
            bullet("bell.badge", "Daily nudge",
                   "An optional reminder keeps your streak alive.")
        }
    }

    private func bullet(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: KakeraSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KakeraColor.vermilion)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KakeraFont.body(16, weight: .semibold)).foregroundStyle(KakeraColor.sumi)
                Text(subtitle).font(KakeraFont.body(14)).foregroundStyle(KakeraColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aiSetup: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.s) {
            Text("Connect AI (optional)")
                .font(KakeraFont.body(15, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)
            Picker("Provider", selection: $aiProviderRaw) {
                Text("Claude").tag(LLMProviderKind.claude.rawValue)
                Text("OpenAI").tag(LLMProviderKind.openai.rawValue)
            }
            .pickerStyle(.segmented)
            SecureField("API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, KakeraSpacing.m)
                .padding(.vertical, KakeraSpacing.s)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(KakeraColor.cardFace))
            Text("Stored in your Keychain. You can add or change it later in Settings.")
                .font(KakeraFont.body(12))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.s) {
            Text("New words per session")
                .font(KakeraFont.body(15, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)
            Picker("New words per session", selection: $newWordsPerDay) {
                ForEach(newWordOptions, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func finish() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { AIConfigStore.setApiKey(key, for: aiKind) }
        hasOnboarded = true
    }
}
