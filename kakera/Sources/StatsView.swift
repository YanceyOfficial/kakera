import SwiftUI
import Charts
import KakeraCore
import KakeraUI

/// The statistics dashboard: quick counts, a 7-day review bar chart (Swift Charts),
/// and overall accuracy. All aggregation is done by the pure `StatsAggregator`.
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("requestRetention") private var requestRetention = 0.9

    @State private var totalWords = 0
    @State private var dueWords = 0
    @State private var bars: [DayBar] = []
    @State private var accuracy: Double?
    @State private var totalReviews = 0
    @State private var streak = 0
    @State private var curve: [RecallPoint] = []
    @State private var atRisk = 0
    @State private var maturityCounts: [MaturityCount] = []

    var body: some View {
        NavigationStack {
            ZStack {
                KakeraColor.washi.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: KakeraSpacing.l) {
                        Text("Stats")
                            .font(KakeraFont.display(34, weight: .bold))
                            .foregroundStyle(KakeraColor.sumi)
                        overviewCard
                        forgettingCard
                        maturityCard
                        activityCard
                    }
                    .padding(KakeraSpacing.l)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: reload)
    }

    // MARK: Sections

    /// One clean strip of the key numbers, divided rather than five separate boxes.
    private var overviewCard: some View {
        HStack(spacing: 0) {
            overviewStat("\(streak)", "Streak")
            overviewDivider
            overviewStat("\(dueWords)", "Due")
            overviewDivider
            overviewStat("\(totalWords)", "Words")
            overviewDivider
            overviewStat(recallText, "Recall")
        }
        .padding(.vertical, KakeraSpacing.l)
        .background(cardBackground)
    }

    private func overviewStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: KakeraSpacing.xs) {
            Text(value)
                .font(KakeraFont.display(26, weight: .bold))
                .foregroundStyle(KakeraColor.sumi)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(KakeraFont.body(12, weight: .medium))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle().fill(KakeraColor.hairline).frame(width: 1, height: 30)
    }

    /// Predicted recall right now, from the forgetting curve.
    private var recallText: String {
        guard let r = curve.first?.recall else { return "—" }
        return "\(Int((r * 100).rounded()))%"
    }

    /// The deck's aggregate forgetting curve: predicted recall over the next 30 days.
    private var forgettingCard: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Forgetting curve")
                    .font(KakeraFont.body(15, weight: .semibold))
                    .foregroundStyle(KakeraColor.sumi)
                Spacer()
                if !curve.isEmpty {
                    Text("\(atRisk) at risk · 7d")
                        .font(KakeraFont.body(13, weight: .medium))
                        .foregroundStyle(atRisk > 0 ? KakeraColor.danger : KakeraColor.inkSecondary)
                }
            }

            if curve.isEmpty {
                emptyHint("Review some words to model your memory.")
            } else {
                Chart {
                    ForEach(curve) { point in
                        LineMark(
                            x: .value("Day", point.dayOffset),
                            y: .value("Recall", point.recall)
                        )
                        .foregroundStyle(KakeraColor.accent)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    RuleMark(y: .value("Target", requestRetention))
                        .foregroundStyle(KakeraColor.inkSecondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        // Leading, so it never meets the 100% label on the trailing axis.
                        .annotation(position: .top, alignment: .leading, spacing: 2) {
                            Text("\(Int(requestRetention * 100))% target")
                                .font(KakeraFont.body(10))
                                .foregroundStyle(KakeraColor.inkSecondary)
                        }
                }
                .chartYScale(domain: 0...1)
                .chartXScale(domain: 0...30)
                // Labels sit outside the plot, on the trailing side (as in Health), each on
                // its own gridline; the week ticks stop short of the trailing edge so the
                // last one is not clipped and never meets the 0% label in the corner.
                .chartYAxis { AxisMarks(position: .trailing, values: [0, 0.5, 1]) { value in
                    AxisGridLine().foregroundStyle(KakeraColor.hairline)
                    AxisValueLabel(horizontalSpacing: 8) {
                        if let d = value.as(Double.self) { Text("\(Int(d * 100))%") }
                    }
                    .font(KakeraFont.body(11))
                    .foregroundStyle(KakeraColor.inkSecondary)
                } }
                .chartXAxis { AxisMarks(values: [0, 7, 14, 21, 28]) { value in
                    AxisValueLabel(verticalSpacing: 8) { if let d = value.as(Int.self) { Text("\(d)d") } }
                        .font(KakeraFont.body(11))
                        .foregroundStyle(KakeraColor.inkSecondary)
                } }
                .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KakeraSpacing.l)
        .background(cardBackground)
    }

    /// Memory maturity: how many words are new / learning / young / mature.
    private var maturityCard: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.m) {
            Text("Memory maturity")
                .font(KakeraFont.body(15, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)

            if maturityCounts.allSatisfy({ $0.count == 0 }) {
                emptyHint("Add words to see your deck's maturity.")
            } else {
                // Laid out by hand rather than as a Chart: Swift Charts moves a horizontal
                // bar chart's category labels on top of the bars when the card is narrow.
                // Here each name has its own column, each count follows its bar.
                let peak = Double(max(1, maturityCounts.map(\.count).max() ?? 1))
                Grid(alignment: .leading, horizontalSpacing: KakeraSpacing.s, verticalSpacing: 10) {
                    ForEach(MaturityBucket.allCases.reversed(), id: \.self) { bucket in
                        let count = maturityCounts.first { $0.bucket == bucket }?.count ?? 0
                        GridRow {
                            Text(bucket.rawValue)
                                .font(KakeraFont.body(12, weight: .medium))
                                .foregroundStyle(KakeraColor.inkSecondary)
                                .gridColumnAlignment(.leading)
                            GeometryReader { proxy in
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        // An empty bucket keeps a neutral sliver, so the row still reads as a bar.
                                        .fill(count == 0 ? KakeraColor.hairline : maturityColor(bucket))
                                        .frame(width: max(3, (proxy.size.width - 30) * Double(count) / peak))
                                    Text("\(count)")
                                        .font(KakeraFont.body(11, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundStyle(KakeraColor.inkSecondary)
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .frame(height: 22)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KakeraSpacing.l)
        .background(cardBackground)
    }

    /// Single-hue sequential ramp: new (light) → mature (full accent).
    private func maturityColor(_ bucket: MaturityBucket) -> Color {
        switch bucket {
        case .new: return KakeraColor.accent.opacity(0.30)
        case .learning: return KakeraColor.accent.opacity(0.50)
        case .young: return KakeraColor.accent.opacity(0.72)
        case .mature: return KakeraColor.accent
        }
    }

    /// Recent activity: the 7-day review bars, with overall accuracy in the header.
    private var activityCard: some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reviews · last 7 days")
                    .font(KakeraFont.body(15, weight: .semibold))
                    .foregroundStyle(KakeraColor.sumi)
                Spacer()
                if let accuracy {
                    Text("\(Int((accuracy * 100).rounded()))% correct")
                        .font(KakeraFont.body(13, weight: .medium))
                        .foregroundStyle(KakeraColor.inkSecondary)
                }
            }

            if totalReviews == 0 {
                emptyHint("No reviews yet — rate a few cards to see your history.")
            } else if bars.allSatisfy({ $0.count == 0 }) {
                emptyHint("No reviews in the last 7 days.")
            } else {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Reviews", bar.count)
                    )
                    .foregroundStyle(KakeraColor.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true, verticalSpacing: 8)
                            .font(KakeraFont.body(11))
                            .foregroundStyle(KakeraColor.inkSecondary)
                    }
                }
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(KakeraColor.hairline)
                    AxisValueLabel(horizontalSpacing: 8)
                        .font(KakeraFont.body(11))
                        .foregroundStyle(KakeraColor.inkSecondary)
                } }
                .frame(height: 160)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KakeraSpacing.l)
        .background(cardBackground)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(KakeraFont.body(14, weight: .regular))
            .foregroundStyle(KakeraColor.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(KakeraColor.cardFace)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(KakeraColor.hairline, lineWidth: 1)
            )
            .shadow(color: KakeraColor.shadow, radius: 8, x: 0, y: 4)
    }

    // MARK: Data

    private func reload() {
        let repository = VocabularyRepository(context: modelContext)
        let entries = (try? repository.entries(for: AppSettings.studyLanguage)) ?? []
        let logs = (try? repository.allReviewLogs()) ?? []
        let now = Date()

        totalWords = entries.count
        dueWords = entries.filter { $0.dueAt <= now }.count
        bars = StatsAggregator.reviewsByDay(logs.map(\.timestamp), lastDays: 7, now: now)
        accuracy = StatsAggregator.accuracy(logs.map(\.isCorrect))
        totalReviews = logs.count
        streak = StatsAggregator.streak(reviewDates: logs.map(\.timestamp), now: now)

        // Memories that have been reviewed at least once model the forgetting curve.
        let memories: [(stability: Double, elapsedDays: Double)] = entries.compactMap { entry in
            let s = entry.scheduling
            guard s.stability > 0, let last = s.lastReview else { return nil }
            return (s.stability, max(0, now.timeIntervalSince(last) / 86_400))
        }
        curve = StatsAggregator.forgettingCurve(memories, overDays: 30)
        atRisk = StatsAggregator.atRisk(memories, threshold: requestRetention, within: 7)
        maturityCounts = StatsAggregator.maturity(entries.map { ($0.scheduling.state, $0.scheduling.stability) })
    }
}
