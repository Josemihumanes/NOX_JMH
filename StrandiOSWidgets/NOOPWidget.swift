import WidgetKit
import SwiftUI
import StrandDesign

/// Timeline entry backed by the latest `WidgetSnapshot` the app published into the App Group.
struct NOOPEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct NOOPProvider: TimelineProvider {
    /// Diagnostic aid: if the App Group itself is unreachable from THIS process (the widget
    /// extension, a separate process from the host app — sideloaded multi-target signing sometimes
    /// fails to provision the extension's half of a shared App Group even when the host app's half
    /// works fine), surface a value that can't be mistaken for real data instead of silently falling
    /// back to the same nice-looking placeholder used for "no data published yet". Real Charge/Rest
    /// scores are 0–100; −1 is not, so it's an unambiguous tell.
    private static var appGroupUnreachableSnapshot: WidgetSnapshot {
        WidgetSnapshot(recovery: -1, bpm: -1, batteryPct: -1, bonded: false, updated: Date(),
                       effort: -1, rest: -1, hrv: -1, restingHr: -1)
    }

    private func currentSnapshot() -> WidgetSnapshot {
        guard UserDefaults(suiteName: "group.com.jmh.nox") != nil else {
            return Self.appGroupUnreachableSnapshot
        }
        return WidgetSnapshot.load() ?? .placeholder
    }

    func placeholder(in context: Context) -> NOOPEntry {
        NOOPEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NOOPEntry) -> Void) {
        completion(NOOPEntry(date: Date(), snapshot: currentSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NOOPEntry>) -> Void) {
        let snap = currentSnapshot()
        // Refresh roughly every 15 minutes; the app also forces a reload when it publishes fresh data.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [NOOPEntry(date: Date(), snapshot: snap)], policy: .after(next)))
    }
}

/// The glanceable widget — the iOS analogue of the macOS menu-bar extra. Recovery, live/last HR,
/// and strap battery.
struct NOOPWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NOOPEntry

    private var snap: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            recoveryGauge
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            rectangular
        case .systemLarge:
            large
        default:
            home
        }
    }

    private var recoveryColor: Color {
        guard let r = snap.recovery else { return StrandPalette.textTertiary }
        return r >= 67 ? StrandPalette.statusPositive : r >= 34 ? StrandPalette.statusWarning : StrandPalette.statusCritical
    }

    /// Effort is on the 0–100 axis (`StrainScorer.maxStrain == 100`), so the fraction is just the value
    /// over 100 — the same input `effortTint` takes on the Today Effort tile.
    private var effortColor: Color {
        guard let e = snap.effort else { return StrandPalette.textTertiary }
        return StrandPalette.effortTint(fraction: Double(e) / 100)
    }

    private var restColor: Color {
        guard let r = snap.rest else { return StrandPalette.textTertiary }
        return StrandPalette.recoveryColor(Double(r))
    }

    private var inlineText: String {
        var parts: [String] = []
        if let r = snap.recovery { parts.append("Charge \(r)%") }
        if let b = snap.bpm { parts.append("\(b) bpm") }
        return parts.isEmpty ? "NOX" : parts.joined(separator: " · ")
    }

    private var recoveryGauge: some View {
        Gauge(value: Double(snap.recovery ?? 0), in: 0...100) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text(snap.recovery.map { "\($0)" } ?? "–")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(recoveryColor)
    }

    /// Lock-Screen rectangular accessory. Two lines (#446): line 1 the Charge headline, line 2 the live
    /// HR alongside Effort so the at-a-glance pair the users asked for both fit the tinted accessory.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(recoveryColor)
                Text("Charge \(snap.recovery.map(String.init) ?? "–")%").font(.headline)
            }
            Text("HR \(snap.bpm.map(String.init) ?? "–") · Effort \(snap.effort.map(String.init) ?? "–")")
                .font(.caption)
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOX").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StrandPalette.textSecondary)
                Spacer()
                Circle().fill(snap.bonded ? StrandPalette.statusPositive : StrandPalette.statusCritical)
                    .frame(width: 8, height: 8)
            }
            Spacer(minLength: 0)
            // Small shows Rest as the headline (battery + Rest + pulse is the trio requested); Medium
            // keeps Charge as the headline since it has room for a full second row (Effort) below.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text((family == .systemSmall ? snap.rest : snap.recovery).map(String.init) ?? "–")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(family == .systemSmall ? restColor : recoveryColor)
                Text("%").font(.headline).foregroundStyle(StrandPalette.textTertiary)
            }
            Text(family == .systemSmall ? "Rest" : "Charge").font(.caption).foregroundStyle(StrandPalette.textTertiary)
            Spacer(minLength: 0)
            HStack {
                Label("\(snap.bpm.map(String.init) ?? "–")", systemImage: "waveform.path.ecg")
                // Medium has room for one more stat (#446): Effort. Small stays Rest headline + HR + battery.
                if family == .systemMedium {
                    Spacer()
                    Label("\(snap.effort.map(String.init) ?? "–")", systemImage: "bolt.fill")
                }
                Spacer()
                Label("\(snap.batteryPct.map { "\($0)%" } ?? "–")", systemImage: "battery.50")
            }
            .font(.caption2).foregroundStyle(StrandPalette.textSecondary)
        }
        .padding(12)
    }

    /// The rich `systemLarge` layout (#446): the Charge headline plus a stat grid of Effort, Rest, HRV,
    /// Resting HR, live HR and strap battery — the "show me more" the issue asked for.
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOX").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StrandPalette.textSecondary)
                Spacer()
                Circle().fill(snap.bonded ? StrandPalette.statusPositive : StrandPalette.statusCritical)
                    .frame(width: 8, height: 8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snap.recovery.map(String.init) ?? "–")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(recoveryColor)
                Text("%").font(.title3).foregroundStyle(StrandPalette.textTertiary)
                Text("Charge").font(.subheadline).foregroundStyle(StrandPalette.textTertiary)
                    .padding(.leading, 2)
            }
            Divider()
            // Two-by-three stat grid of the richer scores. Each cell is a value + label pairing, tinted to
            // match its Today tile where a token exists (Effort, Rest); raw vitals stay neutral.
            HStack(alignment: .top, spacing: 0) {
                statCell("Effort", value: snap.effort.map(String.init), tint: effortColor)
                statCell("Rest", value: snap.rest.map { "\($0)%" }, tint: restColor)
                statCell("HRV", value: snap.hrv.map { "\($0)" }, unit: "ms")
            }
            HStack(alignment: .top, spacing: 0) {
                statCell("Rest HR", value: snap.restingHr.map { "\($0)" }, unit: "bpm")
                statCell("HR", value: snap.bpm.map { "\($0)" }, unit: "bpm")
                statCell("Battery", value: snap.batteryPct.map { "\($0)%" })
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    /// One labelled stat in the large grid — value over a caption, equal-width so the three columns align.
    private func statCell(_ label: LocalizedStringKey, value: String?, unit: String? = nil,
                          tint: Color = StrandPalette.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "–")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(value == nil ? StrandPalette.textTertiary : tint)
                if let unit, value != nil {
                    Text(unit).font(.caption2).foregroundStyle(StrandPalette.textTertiary)
                }
            }
            Text(label).font(.caption2).foregroundStyle(StrandPalette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NOOPWidget: Widget {
    let kind = "NOOPWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NOOPProvider()) { entry in
            if #available(iOS 17.0, *) {
                NOOPWidgetView(entry: entry)
                    .containerBackground(StrandPalette.surfaceBase, for: .widget)
            } else {
                NOOPWidgetView(entry: entry)
                    .padding()
                    .background(StrandPalette.surfaceBase)
            }
        }
        .configurationDisplayName("NOX Charge")
        .description("Charge, Effort, Rest, HRV, resting and live heart rate, and strap battery at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryInline, .accessoryRectangular
        ])
    }
}
