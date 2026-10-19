import SwiftUI

/// Where a speed dial's actions sit around its button: evenly over the quarter circle from straight up to straight
/// left (the button lives in the bottom-trailing corner), `distance` points from its centre.
public enum SpeedDialLayout {
    public static func offset(index: Int, count: Int, distance: CGFloat) -> CGSize {
        let step = count > 1 ? (Double.pi / 2) / Double(count - 1) : 0
        let angle = Double(index) * step  // 0 = up, π/2 = left
        return CGSize(width: -distance * CGFloat(sin(angle)), height: -distance * CGFloat(cos(angle)))
    }
}

/// One choice of a speed dial: an SF Symbol and its name (for VoiceOver and the long-press label).
public struct SpeedDialItem<ID: Hashable & Sendable>: Identifiable {
    public let id: ID
    public let title: LocalizedStringKey
    public let systemImage: String

    public init(id: ID, title: LocalizedStringKey, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

/// A Liquid Glass button for the screen's bottom-trailing corner that stands in for a tab bar (Material's speed
/// dial): it shows the selected item; a press — long, or a tap — opens the others around it, flowing out of the
/// button's glass, and picking one selects it and closes the dial. Built for an iPhone Duo, whose vertical tab
/// bar is narrow (`MainTabView`).
public struct SpeedDial<ID: Hashable & Sendable>: View {
    private let items: [SpeedDialItem<ID>]
    @Binding private var selection: ID
    @Binding private var isOpen: Bool
    @Namespace private var glass

    /// The main button's diameter, and how far the actions sit from its centre.
    static var size: CGFloat { 56 }
    static var actionSize: CGFloat { 48 }
    static var distance: CGFloat { 84 }

    public init(items: [SpeedDialItem<ID>], selection: Binding<ID>, isOpen: Binding<Bool>) {
        self.items = items
        _selection = selection
        _isOpen = isOpen
    }

    private var current: SpeedDialItem<ID>? { items.first { $0.id == selection } }
    private var others: [SpeedDialItem<ID>] { items.filter { $0.id != selection } }

    public var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: KakeraSpacing.l) {
                ZStack {
                    if isOpen {
                        ForEach(Array(others.enumerated()), id: \.element.id) { index, item in
                            action(item)
                                .glassEffect(.regular.interactive(), in: .circle)
                                .glassEffectID(item.id, in: glass)
                                .offset(SpeedDialLayout.offset(index: index, count: others.count, distance: Self.distance))
                        }
                    }
                    mainButton
                        .glassEffect(.regular.tint(KakeraColor.accent.opacity(0.18)).interactive(), in: .circle)
                        .glassEffectID("main", in: glass)
                }
            }
        } else {
            ZStack {
                if isOpen {
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, item in
                        action(item)
                            .background(.ultraThinMaterial, in: Circle())
                            .offset(SpeedDialLayout.offset(index: index, count: others.count, distance: Self.distance))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                mainButton.background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var mainButton: some View {
        Image(systemName: current?.systemImage ?? "circle.grid.2x2")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(KakeraColor.accent)
            .frame(width: Self.size, height: Self.size)
            .contentShape(Circle())
            .onTapGesture { toggle() }
            .onLongPressGesture(minimumDuration: 0.25) { open() }
            .accessibilityElement()
            .accessibilityLabel(current?.title ?? "Menu")
            .accessibilityHint(isOpen ? "Closes the other sections" : "Shows the other sections")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggle() }
    }

    private func action(_ item: SpeedDialItem<ID>) -> some View {
        Button {
            KakeraHaptics.selection()
            withAnimation(KakeraMotion.snappy) {
                selection = item.id
                isOpen = false
            }
        } label: {
            Image(systemName: item.systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(KakeraColor.sumi)
                .frame(width: Self.actionSize, height: Self.actionSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }

    private func open() {
        guard !isOpen else { return }
        KakeraHaptics.impact(.soft)
        withAnimation(KakeraMotion.momentum) { isOpen = true }
    }

    private func toggle() {
        if isOpen {
            withAnimation(KakeraMotion.snappy) { isOpen = false }
        } else {
            open()
        }
    }
}

#Preview("Speed dial") {
    @Previewable @State var selection = 0
    @Previewable @State var isOpen = true
    ZStack(alignment: .bottomTrailing) {
        KakeraColor.washi.ignoresSafeArea()
        SpeedDial(
            items: [
                SpeedDialItem(id: 0, title: "Review", systemImage: "rectangle.on.rectangle.angled"),
                SpeedDialItem(id: 1, title: "Words", systemImage: "text.book.closed"),
                SpeedDialItem(id: 2, title: "Stats", systemImage: "chart.bar.xaxis"),
                SpeedDialItem(id: 3, title: "Settings", systemImage: "gearshape"),
            ],
            selection: $selection, isOpen: $isOpen
        )
        .padding(KakeraSpacing.l)
    }
}
