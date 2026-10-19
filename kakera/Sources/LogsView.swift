import SwiftUI
import KakeraServices
import KakeraUI

/// The Diagnostics screen: browse, filter, share, and clear the app's collected logs.
struct LogsView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", warnings = "Warnings", errors = "Errors"
        var id: String { rawValue }
        var minLevel: LogLevel {
            switch self {
            case .all: return .debug
            case .warnings: return .warning
            case .errors: return .error
            }
        }
    }

    @State private var filter: Filter = .all
    @State private var records: [LogRecord] = []
    @State private var showingClear = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(KakeraSpacing.m)

            List {
                if records.isEmpty {
                    ContentUnavailableView("No logs", systemImage: "doc.text.magnifyingglass",
                                           description: Text("Diagnostic records will appear here."))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(records) { record in
                        row(record).listRowBackground(KakeraColor.cardFace)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(KakeraColor.washi)
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: LogCollector.shared.exportText()) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { showingClear = true } label: {
                        Label("Clear", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(KakeraColor.vermilion)
            }
        }
        .confirmationDialog("Clear all logs?", isPresented: $showingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                LogCollector.shared.clear()
                reload()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: reload)
        .onChange(of: filter) { reload() }
    }

    private func row(_ record: LogRecord) -> some View {
        VStack(alignment: .leading, spacing: KakeraSpacing.xs) {
            HStack(spacing: KakeraSpacing.s) {
                Text(record.level.label)
                    .font(KakeraFont.body(10, weight: .bold))
                    .foregroundStyle(KakeraColor.cardFace)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(color(for: record.level)))
                Text(record.category)
                    .font(KakeraFont.body(12, weight: .medium))
                    .foregroundStyle(KakeraColor.inkSecondary)
                Spacer()
                Text(record.timestamp.formatted(date: .omitted, time: .standard))
                    .font(KakeraFont.phonetic(11))
                    .foregroundStyle(KakeraColor.inkSecondary)
            }
            Text(record.message)
                .font(KakeraFont.body(14))
                .foregroundStyle(KakeraColor.sumi)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .error: return KakeraColor.danger
        case .warning: return KakeraColor.vermilion
        case .info, .debug: return KakeraColor.inkSecondary
        }
    }

    private func reload() {
        records = LogCollector.shared.snapshot(minLevel: filter.minLevel)
    }
}
