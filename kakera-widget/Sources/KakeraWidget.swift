import WidgetKit
import SwiftUI
import KakeraServices
import KakeraUI

/// One timeline entry: the latest snapshot the app published to the App Group.
struct ReviewEntry: TimelineEntry {
    let date: Date
    let snapshot: ReviewWidgetSnapshot?
}

struct ReviewProvider: TimelineProvider {
    /// What the gallery shows: a deck with a few words due.
    static let sample = ReviewWidgetSnapshot(
        dueCount: 12, totalWords: 86, reviewedToday: 7, dueWords: [
            ReviewWidgetWord(lemma: "ephemeral", reading: "/ɪˈfem.ər.əl/", gloss: "adj. 短暂的，转瞬即逝的"),
            ReviewWidgetWord(lemma: "meticulous", reading: "/məˈtɪk.jə.ləs/", gloss: "adj. 一丝不苟的"),
            ReviewWidgetWord(lemma: "serendipity", reading: "/ˌser.ənˈdɪp.ə.ti/", gloss: "n. 机缘巧合"),
        ])

    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> Void) {
        completion(ReviewEntry(date: .now, snapshot: context.isPreview ? Self.sample : WidgetSnapshotStore().read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewEntry>) -> Void) {
        let entry = ReviewEntry(date: .now, snapshot: WidgetSnapshotStore().read())
        // Refresh in an hour; the app also force-reloads whenever the count changes.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// The widget: how many words are due, in the app's serif and its Tokiwa green, and the
/// first of them — a fragment of the deck on the Home Screen. Caught up, it says when the
/// next word comes. Tapping opens the Review tab.
struct ReviewWidgetView: View {
    var entry: ReviewEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: ReviewWidgetSnapshot { entry.snapshot ?? ReviewWidgetSnapshot(dueCount: 0, totalWords: 0) }
    private var due: Int { snapshot.dueCount }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(URL(string: "kakera://review"))
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: KakeraSpacing.xs)
            if due > 0 {
                count
                Spacer(minLength: 10)
                if let word = snapshot.dueWords.first {
                    wordRow(word, size: 16)
                }
            } else {
                caughtUp
            }
            Spacer(minLength: 10)
            progressBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(KakeraColor.cardFace, for: .widget)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: KakeraSpacing.m) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: KakeraSpacing.xs)
                if due > 0 { count } else { caughtUp }
                Spacer(minLength: KakeraSpacing.s)
                progressBar
            }
            .frame(width: 118)

            Rectangle().fill(KakeraColor.hairline).frame(width: 1)

            VStack(alignment: .leading, spacing: KakeraSpacing.s) {
                if snapshot.dueWords.isEmpty {
                    Text(due > 0 ? "Open Kakera to review" : "Nothing waiting")
                        .font(KakeraFont.body(13, weight: .medium))
                        .foregroundStyle(KakeraColor.inkSecondary)
                    if let next = snapshot.nextDueText(now: entry.date), due == 0 {
                        Text(next)
                            .font(KakeraFont.body(12))
                            .foregroundStyle(KakeraColor.inkSecondary)
                    }
                } else {
                    ForEach(Array(snapshot.dueWords.prefix(3).enumerated()), id: \.offset) { _, word in
                        wordRow(word, size: 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(KakeraColor.cardFace, for: .widget)
    }

    /// The mark and the deck's language.
    private var header: some View {
        HStack(alignment: .center) {
            KakeraMark(height: 14).widgetAccentable()
            Spacer()
            Text(snapshot.languageLabel)
                .font(KakeraFont.body(11, weight: .semibold))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
    }

    /// The due count, as the app writes its words: serif, in the accent.
    private var count: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(due)")
                .font(KakeraFont.display(44, weight: .bold))
                .foregroundStyle(KakeraColor.accent)
                .widgetAccentable()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(snapshot.caption)
                .font(KakeraFont.body(12, weight: .medium))
                .foregroundStyle(KakeraColor.inkSecondary)
        }
    }

    private var caughtUp: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("All caught up")
                .font(KakeraFont.display(18, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(snapshot.nextDueText(now: entry.date) ?? "Add a few words")
                .font(KakeraFont.body(12))
                .foregroundStyle(KakeraColor.inkSecondary)
                .lineLimit(1)
        }
    }

    /// A due word with its gloss — the fragment the widget is named for.
    private func wordRow(_ word: ReviewWidgetWord, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(word.lemma)
                .font(KakeraFont.display(size, weight: .semibold))
                .foregroundStyle(KakeraColor.sumi)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(word.gloss)
                .font(KakeraFont.body(11))
                .foregroundStyle(KakeraColor.inkSecondary)
                .lineLimit(1)
        }
    }

    /// Today's progress: reviews done against what's still due.
    @ViewBuilder
    private var progressBar: some View {
        let total = snapshot.reviewedToday + due
        if total > 0 {
            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(KakeraColor.hairline)
                        Capsule().fill(KakeraColor.accent)
                            .frame(width: proxy.size.width * CGFloat(snapshot.reviewedToday) / CGFloat(total))
                            .widgetAccentable()
                    }
                }
                .frame(height: 3)
                Text("\(snapshot.reviewedToday) reviewed today")
                    .font(KakeraFont.body(10, weight: .medium))
                    .foregroundStyle(KakeraColor.inkSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Lock Screen

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(due)")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("due")
                    .font(.system(size: 10, weight: .semibold))
            }
            .widgetAccentable()
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                KakeraMark(height: 10)
                Text("Kakera").font(.system(size: 12, weight: .semibold))
            }
            .widgetAccentable()
            Text(due == 0 ? "All caught up" : "\(due) \(snapshot.caption)")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .lineLimit(1)
            if let word = snapshot.dueWords.first {
                Text("\(word.lemma) · \(word.gloss)")
                    .font(.system(size: 12))
                    .lineLimit(1)
            } else if let next = snapshot.nextDueText(now: entry.date) {
                Text(next).font(.system(size: 12)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        if due == 0 {
            Text("Kakera · all caught up")
        } else if let word = snapshot.dueWords.first {
            Text("\(due) \(snapshot.caption) · \(word.lemma)")
        } else {
            Text("\(due) \(snapshot.caption)")
        }
    }
}

struct ReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReviewWidget", provider: ReviewProvider()) { entry in
            ReviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Words due")
        .description("How many words are due for review, and the next of them.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct KakeraWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReviewWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    ReviewWidget()
} timeline: {
    ReviewEntry(date: .now, snapshot: ReviewProvider.sample)
    ReviewEntry(date: .now, snapshot: ReviewWidgetSnapshot(dueCount: 0, totalWords: 86, reviewedToday: 19, nextDueAt: .now.addingTimeInterval(5 * 3_600)))
}

#Preview("Medium", as: .systemMedium) {
    ReviewWidget()
} timeline: {
    ReviewEntry(date: .now, snapshot: ReviewProvider.sample)
    ReviewEntry(date: .now, snapshot: ReviewWidgetSnapshot(dueCount: 0, totalWords: 86, reviewedToday: 19, nextDueAt: .now.addingTimeInterval(30 * 3_600)))
}
