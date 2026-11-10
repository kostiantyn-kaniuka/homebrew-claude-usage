import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let s = context.isPreview ? (UsageStore.load() ?? .sample) : UsageStore.load()
        completion(UsageEntry(date: Date(), snapshot: s))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let now = Date()
        let entry = UsageEntry(date: now, snapshot: UsageStore.load())
        // The helper app pushes reloads after each fetch; this is just a fallback.
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
    }
}

// MARK: - Pieces

private func barColor(_ l: UsageLimit, percent: Double, primary: Bool) -> Color {
    if l.severity == "critical" || percent >= 95 { return .red }
    if l.severity == "warning" || percent >= 80 { return .orange }
    return primary ? Color(red: 0.20, green: 0.47, blue: 0.96) : Color(red: 0.42, green: 0.65, blue: 0.97)
}

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: max(geo.size.width * fraction, fraction > 0 ? 4 : 0))
                    .widgetAccentable()
            }
        }
        .frame(height: 6)
    }
}

struct Header: View {
    let snapshot: UsageSnapshot?

    var body: some View {
        HStack(spacing: 6) {
            MascotView().frame(height: 14)
            Text("Claude").font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 4)
            if let s = snapshot {
                Text(s.error ?? "Updated \(UsageFormat.time(s.updatedAt))")
                    .font(.system(size: 9))
                    .foregroundStyle(s.error == nil ? Color.secondary : Color.orange)
                    .lineLimit(1)
            }
        }
    }
}

struct UsageRow: View {
    let limit: UsageLimit
    let now: Date
    let primary: Bool

    var body: some View {
        let p = limit.effectivePercent(at: now)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(limit.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(UsageFormat.resetText(limit.resetsAt, now: now))
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 108, alignment: .leading)
            UsageBar(fraction: p / 100, color: barColor(limit, percent: p, primary: primary))
            Text("\(Int(p))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

struct EmptyState: View {
    var body: some View {
        Text("Open the Claude Usage app to start")
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sizes

struct MediumView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(snapshot: entry.snapshot)
            if let s = entry.snapshot, !s.limits.isEmpty {
                Spacer(minLength: 6)
                VStack(spacing: 9) {
                    ForEach(Array(s.limits.prefix(3).enumerated()), id: \.element.id) { i, l in
                        UsageRow(limit: l, now: entry.date, primary: i == 0)
                    }
                }
                Spacer(minLength: 0)
            } else {
                EmptyState()
            }
        }
    }
}

struct SmallView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                MascotView().frame(height: 14)
                Text("Claude").font(.system(size: 13, weight: .semibold))
            }
            if let s = entry.snapshot, let session = s.limits.first {
                let p = session.effectivePercent(at: entry.date)
                Spacer(minLength: 4)
                Text("Current session").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("\(Int(p))%").font(.system(size: 30, weight: .semibold).monospacedDigit())
                UsageBar(fraction: p / 100, color: barColor(session, percent: p, primary: true))
                    .padding(.vertical, 3)
                Text(UsageFormat.resetText(session.resetsAt, now: entry.date))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                if s.limits.count > 1 {
                    let w = s.limits[1]
                    Spacer(minLength: 2)
                    Text("Weekly \(Int(w.effectivePercent(at: entry.date)))%")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
            } else {
                EmptyState()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        Group {
            if family == .systemSmall { SmallView(entry: entry) } else { MediumView(entry: entry) }
        }
        .containerBackground(.background, for: .widget)
    }
}

@main
struct ClaudeUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsageWidget", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Your Claude plan limits: session, weekly and per-model.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
