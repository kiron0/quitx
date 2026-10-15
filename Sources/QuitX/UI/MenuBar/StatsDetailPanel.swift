import AppKit
import Combine
import SwiftUI

@MainActor
final class StatsDetailModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case battery = "Battery"
    }

    @Published var mode: Mode = .cpu
    @Published var arrowX: CGFloat? = nil
    @Published var contentHeight: CGFloat = 380

    @Published var cpu: Double = 0
    @Published var systemPct: Double = 0
    @Published var userPct: Double = 0
    @Published var idlePct: Double = 100
    @Published var perCore: [Double] = []
    @Published var cpuLevels: [SystemUsage.CpuLevel] = []
    @Published var load1: Double = 0
    @Published var load5: Double = 0
    @Published var load15: Double = 0
    @Published var uptime: String = ""

    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var cpuTop: [TopProcessSampler.Proc] = []
    @Published var memTop: [TopProcessSampler.Proc] = []

    @Published var memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var memApp: UInt64 = 0
    @Published var memWired: UInt64 = 0
    @Published var memCompressed: UInt64 = 0
    @Published var memCached: UInt64 = 0
    @Published var memFree: UInt64 = 0
    @Published var swapUsed: UInt64 = 0
    @Published var swapTotal: UInt64 = 0
    @Published var battery: BatterySnapshot?

    @Published var showToast: Bool = false
    @Published private(set) var toastMessage: String = ""
    @Published private(set) var toastIsError: Bool = false

    var memUsed: UInt64 { memApp + memWired + memCompressed }

    private var timer: Timer?
    private var sampleGeneration = 0
    private var topProcessTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var sampleFailureToastShown = false
    private var toastTask: Task<Void, Never>?
    private static let historyLimit = 180

    func toast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        toastMessage = message
        toastIsError = isError
        showToast = true
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.showToast = false
        }
    }

    func start() {
        stop()
        sampleFailureToastShown = false
        cpuLevels = SystemUsage.cpuTopology().levels
        tick()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        sampleGeneration += 1
        topProcessTask?.cancel()
        topProcessTask = nil
        batteryTask?.cancel()
        batteryTask = nil
    }

    private func tick() {
        let generation = sampleGeneration

        let detail = SystemUsage.cpuDetail(consumer: "statsPanel")
        cpu = detail.total
        systemPct = detail.system
        userPct = detail.user
        idlePct = detail.idle
        perCore = detail.perCore

        let load = SystemUsage.loadAverages()
        load1 = load.0
        load5 = load.1
        load15 = load.2
        uptime = SystemUsage.uptimeDescription()

        if let breakdown = SystemUsage.memoryBreakdown() {
            memTotal = breakdown.total
            memApp = breakdown.app
            memWired = breakdown.wired
            memCompressed = breakdown.compressed
            memCached = breakdown.cached
            memFree = breakdown.free
        }
        let swap = SystemUsage.swapUsage()
        swapUsed = swap.used
        swapTotal = swap.total

        if ConfigStore.shared.config.batteryMenuBarEnabled {
            if batteryTask == nil {
                batteryTask = Task { [weak self] in
                    let snapshot = await Task.detached(priority: .utility) {
                        BatteryDetailSampler.snapshot()
                    }.value
                    guard let self else { return }
                    defer {
                        if self.sampleGeneration == generation {
                            self.batteryTask = nil
                        }
                    }
                    guard !Task.isCancelled, self.sampleGeneration == generation else { return }
                    self.battery = snapshot
                }
            }
        } else {
            batteryTask?.cancel()
            batteryTask = nil
            battery = nil
        }

        appendHistory(&cpuHistory, value: cpu)
        if memTotal > 0 {
            appendHistory(&memHistory, value: Double(memUsed) / Double(memTotal) * 100)
        }

        guard topProcessTask == nil else { return }
        topProcessTask = Task { [weak self] in
            let top = await TopProcessSampler.sample()
            guard let self else { return }
            defer {
                if self.sampleGeneration == generation {
                    self.topProcessTask = nil
                }
            }
            guard !Task.isCancelled, self.sampleGeneration == generation else { return }
            self.cpuTop = top.cpu
            self.memTop = top.mem
            if top.cpu.isEmpty, top.mem.isEmpty, !self.sampleFailureToastShown {
                self.sampleFailureToastShown = true
                self.toast("Process list unavailable", isError: true)
            }
        }
    }

    private func appendHistory(_ history: inout [Double], value: Double) {
        history.append(value)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }
}

private enum StatsContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum StatsTheme {
    static let red = Color(red: 0.94, green: 0.27, blue: 0.30)
    static let blue = Color(red: 0.13, green: 0.55, blue: 0.95)
    static let chartBlue = Color(red: 0.15, green: 0.55, blue: 0.98)
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.15)
    static let pink = Color(red: 0.98, green: 0.30, blue: 0.45)
    static let gray = Color.primary.opacity(0.25)
    static let yellow = Color(red: 0.98, green: 0.80, blue: 0.20)
    static let green = Color(red: 0.20, green: 0.72, blue: 0.35)

    static func cpuLevelColor(index: Int) -> Color {
        let goldenRatio = 0.618_033_988_75
        let hue = (0.56 + Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.72, brightness: 0.92)
    }
}

private struct SegmentedRing: View {
    let segments: [(fraction: Double, color: Color)]
    let centerText: String
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        var accumulated: Double = 0
        let arcs: [(from: Double, to: Double, color: Color)] = segments.map { segment in
            let start = accumulated
            accumulated += segment.fraction
            return (start, accumulated, segment.color)
        }
        return ZStack {
            Circle()
                .stroke(StatsTheme.gray, lineWidth: lineWidth)
            ForEach(arcs.indices, id: \.self) { index in
                let arc = arcs[index]
                Circle()
                    .trim(from: CGFloat(arc.from), to: CGFloat(arc.to))
                    .stroke(
                        arc.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Text(centerText)
                .font(.system(size: size * 0.22, weight: .semibold).monospacedDigit())
        }
        .frame(width: size, height: size)
    }
}

private struct MemoryUsageGauge: View {
    let fraction: Double

    private func point(angleDegrees: Double, radius: Double, center: CGPoint) -> CGPoint {
        let radians = angleDegrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }

    private func zonePath(from: Double, to: Double, center: CGPoint, radius: Double) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180 + 180 * from),
                endAngle: .degrees(180 + 180 * to),
                clockwise: false
            )
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let center = CGPoint(x: width / 2, y: geometry.size.height - 6)
                let radius = width / 2 - 6
                let clamped = min(1, max(0, fraction))

                ZStack {
                    zonePath(from: 0, to: 1, center: center, radius: radius)
                        .stroke(StatsTheme.gray, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                    zonePath(from: 0, to: clamped, center: center, radius: radius)
                        .stroke(StatsTheme.blue, style: StrokeStyle(lineWidth: 7, lineCap: .butt))

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(angleDegrees: 180 + 180 * clamped, radius: radius - 8, center: center))
                    }
                    .stroke(QuitXTheme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    Circle()
                        .fill(QuitXTheme.accent)
                        .frame(width: 6, height: 6)
                        .position(center)
                }
            }
            Text("Memory used")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatsHistoryChart: View {
    let values: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, maxValue > 0 else {
                let placeholder = CGRect(x: 0, y: size.height - 1, width: size.width, height: 1)
                context.fill(Path(placeholder), with: .color(color.opacity(0.35)))
                return
            }
            let stepX = size.width / CGFloat(values.count - 1)
            func yPosition(_ value: Double) -> CGFloat {
                let ratio = min(1, max(0, value / maxValue))
                return size.height - CGFloat(ratio) * (size.height - 2) - 1
            }
            var line = Path()
            line.move(to: CGPoint(x: 0, y: yPosition(values[0])))
            for index in values.indices.dropFirst() {
                line.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: yPosition(values[index])))
            }
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.95), color.opacity(0.45)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct CoreBars: View {
    let perCore: [Double]
    let height: CGFloat = 34

    var body: some View {
        HStack(spacing: 4) {
            ForEach(perCore.indices, id: \.self) { index in
                let value = perCore[index]
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(StatsTheme.blue)
                        .frame(height: max(3, height * CGFloat(min(100, max(0, value))) / 100))
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.07))
                )
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Color.secondary)
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let dotColor {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.85))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.primary)
        }
        .frame(height: 18)
    }
}

private final class ProcessRowHover: ObservableObject {
    @Published var hovered = false
}

private struct ProcessRow: View {
    let proc: TopProcessSampler.Proc
    let showCpu: Bool
    let onCopy: (String) -> Void

    @StateObject private var hover = ProcessRowHover()

    private var valueText: String {
        showCpu ? String(format: "%.1f%%", proc.cpu) : MemoryFormatter.format(bytes: proc.bytes)
    }

    var body: some View {
        HStack(spacing: 7) {
            AppIconView(bundleId: nil, pid: proc.id, size: 14, cornerRadius: 2)
            Text(proc.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            Text(valueText)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
        .padding(.horizontal, 5)
        .frame(height: 21)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(hover.hovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { hover.hovered = $0 }
        .help("Click to copy")
        .onTapGesture {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("\(proc.name) \(valueText)", forType: .string)
            onCopy("Copied \(proc.name)")
        }
    }
}

private struct ProcessList: View {
    let procs: [TopProcessSampler.Proc]
    let showCpu: Bool
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Process")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("Usage")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 5)
            if procs.isEmpty {
                Text("Sampling...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .frame(height: 40, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(procs) { proc in
                    ProcessRow(proc: proc, showCpu: showCpu, onCopy: onCopy)
                }
            }
        }
    }
}

struct StatsDetailView: View {
    @ObservedObject var model: StatsDetailModel
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared

    private let panelWidth: CGFloat = 270
    private let headerHeight: CGFloat = 12
    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 140
    }

    private func statsTabFooterButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5))
                    .foregroundStyle(QuitXTheme.accent)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func openActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        )
    }

    private func openBatterySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    private func windowTitleHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(QuitXTheme.accent.opacity(0.14))
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(QuitXTheme.accent)
            }
            .frame(width: 20, height: 20)

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.primary)

            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.top, 1)
        .padding(.bottom, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 12)

            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch model.mode {
                    case .cpu:
                        cpuContent
                    case .memory:
                        memoryContent
                    case .battery:
                        batteryContent
                    }
                }
                .padding(10)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: StatsContentHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                )
            }
            .onPreferenceChange(StatsContentHeightKey.self) { height in
                Task { @MainActor in
                    let clamped = min(height, self.maxHeight)
                    if abs(self.model.contentHeight - clamped) > 0.5 {
                        self.model.contentHeight = clamped
                    }
                }
            }
        }
        .frame(width: panelWidth, height: headerHeight + model.contentHeight, alignment: .top)
        .arrowPopoverChrome(arrowX: model.arrowX, classicBackground: AnyView(QuitXTheme.popoverBackground))
        .overlay(alignment: .bottom) {
            if model.showToast {
                ToastView(message: model.toastMessage, isError: model.toastIsError)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.showToast)
    }

    private var cpuContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            windowTitleHeader(title: "CPU Usage", symbol: "cpu")

            card {
                HStack(spacing: 16) {
                    SegmentedRing(
                        segments: [
                            (model.systemPct / 100, StatsTheme.red),
                            (model.userPct / 100, StatsTheme.blue),
                            (model.idlePct / 100, StatsTheme.gray)
                        ],
                        centerText: pct(model.cpu),
                        size: 78,
                        lineWidth: 8.5
                    )
                    VStack(spacing: 3) {
                        SegmentedRing(
                            segments: [
                                (model.load1 / Double(max(1, model.cpuLevels.reduce(0) { $0 + $1.logicalCores })), StatsTheme.blue)
                            ],
                            centerText: String(format: "%.2f", model.load1),
                            size: 50,
                            lineWidth: 5.5
                        )
                        Text("load")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Usage History")
                card {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            StatsHistoryChart(values: model.cpuHistory, maxValue: 100, color: StatsTheme.chartBlue)
                            if model.cpuHistory.count < 2 {
                                Text("Collecting samples…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        if !model.perCore.isEmpty {
                            CoreBars(perCore: model.perCore)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Details")
                card {
                    VStack(alignment: .leading, spacing: 4.5) {
                        DetailRow(title: "System:", value: pct(model.systemPct), dotColor: StatsTheme.red)
                        DetailRow(title: "User:", value: pct(model.userPct), dotColor: StatsTheme.blue)
                        DetailRow(title: "Idle:", value: pct(model.idlePct), dotColor: StatsTheme.gray)
                        ForEach(model.cpuLevels) { level in
                            DetailRow(
                                title: "\(level.name) cores:",
                                value: "\(level.logicalCores)",
                                dotColor: StatsTheme.cpuLevelColor(index: level.index)
                            )
                        }
                        DetailRow(title: "Uptime:", value: model.uptime)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Average Load")
                card {
                    VStack(alignment: .leading, spacing: 4.5) {
                        DetailRow(title: "1 minute:", value: String(format: "%.2f", model.load1))
                        DetailRow(title: "5 minutes:", value: String(format: "%.2f", model.load5))
                        DetailRow(title: "15 minutes:", value: String(format: "%.2f", model.load15))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Top Processes")
                card {
                    ProcessList(procs: model.cpuTop, showCpu: true, onCopy: { model.toast($0) })
                }
            }

            statsTabFooterButton(
                title: "Open Activity Monitor",
                symbol: "gauge.with.dots.needle.67percent"
            ) {
                openActivityMonitor()
            }
        }
    }

    private var memoryContent: some View {
        let usedFraction = model.memTotal > 0 ? Double(model.memUsed) / Double(model.memTotal) : 0
        return VStack(alignment: .leading, spacing: 10) {
            windowTitleHeader(
                title: "Memory Usage",
                symbol: "memorychip"
            )

            card {
                HStack(alignment: .center, spacing: 16) {
                    MemoryUsageGauge(fraction: usedFraction)
                        .frame(width: 90, height: 72)
                    SegmentedRing(
                        segments: [
                            (Double(model.memApp) / Double(model.memTotal), StatsTheme.blue),
                            (Double(model.memWired) / Double(model.memTotal), StatsTheme.orange),
                            (Double(model.memCompressed) / Double(model.memTotal), StatsTheme.pink)
                        ],
                        centerText: pct(usedFraction * 100),
                        size: 72,
                        lineWidth: 8
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Usage History")
                card {
                    ZStack {
                        StatsHistoryChart(values: model.memHistory, maxValue: 100, color: StatsTheme.chartBlue)
                        if model.memHistory.count < 2 {
                            Text("Collecting samples…")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Details")
                card {
                    VStack(alignment: .leading, spacing: 4.5) {
                        DetailRow(title: "Used:", value: MemoryFormatter.format(bytes: model.memUsed))
                        stackedMemoryBar(total: Double(model.memTotal))
                            .padding(.vertical, 2)
                        DetailRow(title: "App:", value: MemoryFormatter.format(bytes: model.memApp), dotColor: StatsTheme.blue)
                        DetailRow(title: "Wired:", value: MemoryFormatter.format(bytes: model.memWired), dotColor: StatsTheme.orange)
                        DetailRow(
                            title: "Compressed:",
                            value: MemoryFormatter.format(bytes: model.memCompressed),
                            dotColor: StatsTheme.pink
                        )
                        DetailRow(title: "Cached:", value: MemoryFormatter.format(bytes: model.memCached))
                        DetailRow(title: "Free:", value: MemoryFormatter.format(bytes: model.memFree), dotColor: StatsTheme.gray)
                        DetailRow(
                            title: "Swap:",
                            value: model.swapUsed > 0 ? MemoryFormatter.format(bytes: model.swapUsed) : "None",
                            dotColor: StatsTheme.yellow
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionHeader(title: "Top Processes")
                card {
                    ProcessList(procs: model.memTop, showCpu: false, onCopy: { model.toast($0) })
                }
            }

            statsTabFooterButton(
                title: "Open Activity Monitor",
                symbol: "waveform.path.ecg"
            ) {
                openActivityMonitor()
            }
        }
    }

    private var batteryContent: some View {
        Group {
            if let battery = model.battery {
                VStack(alignment: .leading, spacing: 10) {
                    windowTitleHeader(
                        title: "Battery Status",
                        symbol: battery.isCharging ? "bolt.fill" : "battery.100"
                    )

                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: BatteryDetailSampler.menuBarSymbolName(
                                    percent: battery.percent,
                                    charging: battery.isCharging
                                ))
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.primary)
                                Text("\(battery.percent)%")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                            }
                            Text("Power Source: \(battery.isACPower ? "Power Adapter" : "Battery")")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                            if let timeText = batteryNativeTimeText(battery) {
                                Text(timeText)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            if battery.isACPower, let limit = battery.chargingLimitPercent {
                                let reachedLimit = battery.percent >= limit
                                Text("\(reachedLimit ? "Charged to" : "Charging to") \(limit)% Limit")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        SectionHeader(title: "Details")
                        card {
                            VStack(alignment: .leading, spacing: 4.5) {
                                let showFlow = battery.isCharging || !battery.isACPower
                                if showFlow, let watts = battery.powerW {
                                    DetailRow(title: "Power:", value: String(format: "%.1f W", watts))
                                }
                                if showFlow, let amps = battery.amperageMA {
                                    DetailRow(
                                        title: "Amperage:",
                                        value: String(format: "%+.0f mA", Double(amps)),
                                        dotColor: StatsTheme.orange
                                    )
                                }
                                if let volts = battery.voltageMV {
                                    DetailRow(title: "Voltage:", value: String(format: "%.2f V", Double(volts) / 1000.0))
                                }
                                if let temp = battery.tempC {
                                    DetailRow(
                                        title: "Temperature:",
                                        value: String(format: "%.1f °C", temp),
                                        dotColor: temp > 35 ? StatsTheme.orange : StatsTheme.green
                                    )
                                }
                                if let charge = battery.chargeMAh, let design = battery.designCapacityMAh, design > 0 {
                                    DetailRow(
                                        title: "Charge:",
                                        value: "\(charge) / \(design) mAh",
                                        dotColor: StatsTheme.blue
                                    )
                                }
                                if let cycles = battery.cycleCount {
                                    DetailRow(title: "Cycle Count:", value: "\(cycles)")
                                }
                                if let health = battery.healthPercent {
                                    DetailRow(title: "Max Capacity:", value: "\(health)%")
                                }
                            }
                        }
                    }

                    statsTabFooterButton(
                        title: "Open Battery Settings",
                        symbol: "batteryblock"
                    ) {
                        openBatterySettings()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "batteryblock.slash")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.secondary)
                    Text("No battery detected")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            }
        }
    }

    private func batteryNativeTimeText(_ battery: BatterySnapshot) -> String? {
        if battery.isCharging {
            return BatteryDetailSampler.formatDuration(minutes: battery.timeToFullMin ?? 0)
                .map { "Time to Full: \($0)" }
        }
        if !battery.isACPower {
            return BatteryDetailSampler.formatDuration(minutes: battery.timeToEmptyMin ?? 0)
                .map { "Remaining: \($0)" }
        }
        return nil
    }

    private func stackedMemoryBar(total: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 1.5) {
                segment(width: total > 0 ? width * Double(model.memApp) / total : 0, color: StatsTheme.blue)
                segment(width: total > 0 ? width * Double(model.memWired) / total : 0, color: StatsTheme.orange)
                segment(width: total > 0 ? width * Double(model.memCompressed) / total : 0, color: StatsTheme.pink)
            }
        }
        .frame(height: 7)
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: max(0, width))
    }
}

@MainActor
final class StatsDetailController {
    static let shared = StatsDetailController()

    private var window: ArrowPopoverWindow?
    private var model: StatsDetailModel?
    private var hostView: NSHostingView<StatsDetailView>?
    private var heightObserver: AnyCancellable?
    private var localMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var lastCloseTimestamp: Date = .distantPast
    private var lastClosedMode: StatsDetailModel.Mode?
    private var frontmostAtShow: NSRunningApplication?
    private weak var currentAnchorButton: NSStatusBarButton?
    private var isSwitchingWindow = false

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle(from button: NSStatusBarButton, mode: StatsDetailModel.Mode, anchorScreenX: CGFloat? = nil) {
        if isVisible {
            if model?.mode == mode && currentAnchorButton == button {

                closeAndReset()
            } else {

                switchTo(button: button, mode: mode, anchorScreenX: anchorScreenX)
            }
        } else {

            if lastClosedMode == mode && Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                lastClosedMode = nil
                return
            }
            show(from: button, mode: mode, anchorScreenX: anchorScreenX)
        }
    }

    private func switchTo(button: NSStatusBarButton, mode: StatsDetailModel.Mode, anchorScreenX: CGFloat?) {
        isSwitchingWindow = true

        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        removeMonitors()
        heightObserver = nil
        window?.orderOut(nil)
        model?.stop()
        currentAnchorButton = nil
        lastClosedMode = nil
        isSwitchingWindow = false

        show(from: button, mode: mode, anchorScreenX: anchorScreenX)
    }

    private func closeAndReset() {
        isSwitchingWindow = false
        lastCloseTimestamp = Date()
        lastClosedMode = model?.mode
        window?.orderOut(nil)
        model?.stop()
        heightObserver = nil
        currentAnchorButton = nil
        removeMonitors()
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        restoreFrontmost()
    }

    func show(from button: NSStatusBarButton, mode: StatsDetailModel.Mode, anchorScreenX: CGFloat? = nil) {
        guard let buttonWindow = button.window else { return }
        StatusItemController.shared?.closePopover()
        lastClosedMode = nil
        currentAnchorButton = button

        let model = self.model ?? StatsDetailModel()
        model.mode = mode
        self.model = model

        let hostView = NSHostingView(rootView: StatsDetailView(model: model))
        self.hostView = hostView

        let win: ArrowPopoverWindow
        if let existing = window {
            win = existing
        } else {
            win = ArrowPopoverWindow()
            window = win
        }
        win.contentView = hostView

        let size = hostView.fittingSize
        win.setContentSize(size)

        let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
        let targetMidX = anchorScreenX ?? buttonScreenRect.midX
        var originX = targetMidX - size.width / 2
        if let screen = buttonWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4,
                          min(originX, screen.visibleFrame.maxX - size.width - 4))
        }

        let originY = buttonScreenRect.minY - size.height - 2
        model.arrowX = targetMidX - originX
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.invalidateShadow()

        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isSwitchingWindow, self.isVisible else { return }

                let mouseLoc = NSEvent.mouseLocation
                if let statsBtn = StatusItemController.shared?.statsButton,
                   let btnWin = statsBtn.window,
                   btnWin.convertToScreen(statsBtn.bounds).contains(mouseLoc) {
                    return
                }
                if let statusBtn = StatusItemController.shared?.statusBarButton,
                   let btnWin = statusBtn.window,
                   btnWin.convertToScreen(statusBtn.bounds).contains(mouseLoc) {
                    return
                }
                self.close()
            }
        }

        heightObserver = model.$contentHeight
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.resizeToFit()
                }
            }

        model.start()
        frontmostAtShow = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    private func resizeToFit() {
        guard isVisible, let win = window, let hostView else { return }
        let size = hostView.fittingSize
        guard size.height > 1 else { return }
        var frame = win.frame
        guard abs(frame.height - size.height) > 0.5 || abs(frame.width - size.width) > 0.5 else {
            return
        }
        frame.origin.y -= (size.height - frame.height)
        frame.size = size
        win.setFrame(frame, display: win.isVisible, animate: false)
        win.invalidateShadow()
    }

    func close() {
        guard isVisible else { return }
        lastCloseTimestamp = Date()
        lastClosedMode = model?.mode
        window?.orderOut(nil)
        model?.stop()
        heightObserver = nil
        currentAnchorButton = nil
        removeMonitors()
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        restoreFrontmost()
    }

    private func restoreFrontmost() {
        guard NSApp.isActive,
              let prev = frontmostAtShow,
              prev != NSRunningApplication.current,
              !prev.isTerminated else {
            frontmostAtShow = nil
            return
        }
        frontmostAtShow = nil
        prev.activate(options: [])
    }

    private func installMonitors() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self, self.isVisible, event.keyCode == 53 else { return event }
            self.close()
            return nil
        }
    }

    private func removeMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
