import AppKit
import Combine
import SwiftUI

@MainActor
final class StatsDetailModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case cpu = "CPU"
        case ram = "RAM"
    }

    @Published var mode: Mode = .cpu
    @Published var arrowX: CGFloat? = nil
    @Published var contentHeight: CGFloat = 520

    @Published var cpu: Double = 0
    @Published var systemPct: Double = 0
    @Published var userPct: Double = 0
    @Published var idlePct: Double = 100
    @Published var perCore: [Double] = []
    @Published var efficiencyCores: Int = 0
    @Published var performanceCores: Int = 0
    @Published var efficiencyPct: Double = 0
    @Published var performancePct: Double = 0
    @Published var load1: Double = 0
    @Published var load5: Double = 0
    @Published var load15: Double = 0
    @Published var freqAllMHz: Int = 0
    @Published var freqEfficiencyMHz: Int = 0
    @Published var freqPerformanceMHz: Int = 0
    @Published var uptime: String = ""

    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var cpuTop: [TopProcessSampler.Proc] = []
    @Published var memTop: [TopProcessSampler.Proc] = []

    @Published var memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var memApp: UInt64 = 0
    @Published var memWired: UInt64 = 0
    @Published var memCompressed: UInt64 = 0
    @Published var memFree: UInt64 = 0
    @Published var swapUsed: UInt64 = 0
    @Published var swapTotal: UInt64 = 0

    @Published var showToast: Bool = false
    @Published private(set) var toastMessage: String = ""
    @Published private(set) var toastIsError: Bool = false

    var memUsed: UInt64 { memApp + memWired + memCompressed }

    private var timer: Timer?
    private var sampleGeneration = 0
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
        let counts = SystemUsage.coreCounts()
        efficiencyCores = counts.efficiency
        performanceCores = counts.performance
        let freqs = SystemUsage.frequenciesMHz()
        freqAllMHz = freqs.allMHz
        freqEfficiencyMHz = freqs.efficiencyMHz
        freqPerformanceMHz = freqs.performanceMHz
        tick()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        sampleGeneration += 1
    }

    private func tick() {
        sampleGeneration += 1
        let generation = sampleGeneration

        let detail = SystemUsage.cpuDetail(consumer: "statsPanel")
        cpu = detail.total
        systemPct = detail.system
        userPct = detail.user
        idlePct = detail.idle
        perCore = detail.perCore

        if efficiencyCores > 0, detail.perCore.count >= efficiencyCores {
            let slice = detail.perCore[0..<efficiencyCores]
            efficiencyPct = slice.reduce(0, +) / Double(slice.count)
        }
        if performanceCores > 0, detail.perCore.count >= efficiencyCores + performanceCores {
            let slice = detail.perCore[efficiencyCores..<(efficiencyCores + performanceCores)]
            performancePct = slice.reduce(0, +) / Double(slice.count)
        }

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
            memFree = breakdown.free
        }
        let swap = SystemUsage.swapUsage()
        swapUsed = swap.used
        swapTotal = swap.total

        appendHistory(&cpuHistory, value: cpu)
        if memTotal > 0 {
            appendHistory(&memHistory, value: Double(memUsed) / Double(memTotal) * 100)
        }

        Task { [weak self] in
            let top = await TopProcessSampler.sample()
            guard let self, !Task.isCancelled, self.sampleGeneration == generation else { return }
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
    static let teal = Color(red: 0.20, green: 0.85, blue: 0.78)
    static let purple = Color(red: 0.45, green: 0.45, blue: 0.95)
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.15)
    static let pink = Color(red: 0.98, green: 0.30, blue: 0.45)
    static let gray = Color.primary.opacity(0.25)
    static let green = Color(red: 0.30, green: 0.80, blue: 0.35)
    static let yellow = Color(red: 0.98, green: 0.80, blue: 0.20)
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

private struct PressureGauge: View {
    let fraction: Double

    private var label: String {
        if fraction < 0.6 { return "Good" }
        if fraction < 0.8 { return "Warning" }
        return "Critical"
    }

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
                    zonePath(from: 0, to: 0.6, center: center, radius: radius)
                        .stroke(StatsTheme.green, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                    zonePath(from: 0.6, to: 0.8, center: center, radius: radius)
                        .stroke(StatsTheme.yellow, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                    zonePath(from: 0.8, to: 1.0, center: center, radius: radius)
                        .stroke(StatsTheme.red, style: StrokeStyle(lineWidth: 7, lineCap: .butt))

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
            Text(label)
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
    let efficiencyCount: Int
    let height: CGFloat = 34

    var body: some View {
        HStack(spacing: 4) {
            ForEach(perCore.indices, id: \.self) { index in
                let value = perCore[index]
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < efficiencyCount ? StatsTheme.teal : StatsTheme.purple)
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
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.secondary)
                .tracking(1.0)
                .fixedSize()
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.85))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
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
            if let icon = AppIconCache.icon(for: nil, pid: proc.id) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.secondary)
            }
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

    private let panelWidth: CGFloat = 270
    private let headerHeight: CGFloat = 50
    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 140
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $model.mode) {
                ForEach(StatsDetailModel.Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch model.mode {
                    case .cpu:
                        cpuContent
                    case .ram:
                        ramContent
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
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
                    .padding(.bottom, 14)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.showToast)
    }

    private var cpuContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                SegmentedRing(
                    segments: [
                        (model.systemPct / 100, StatsTheme.red),
                        (model.userPct / 100, StatsTheme.blue),
                        (model.idlePct / 100, StatsTheme.gray)
                    ],
                    centerText: pct(model.cpu),
                    size: 82,
                    lineWidth: 9
                )
                VStack(spacing: 4) {
                    SegmentedRing(
                        segments: [
                            (model.load1 / Double(max(1, model.efficiencyCores + model.performanceCores)), StatsTheme.blue)
                        ],
                        centerText: String(format: "%.2f", model.load1),
                        size: 52,
                        lineWidth: 6
                    )
                    Text("load")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "USAGE HISTORY")
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
                            CoreBars(perCore: model.perCore, efficiencyCount: model.efficiencyCores)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "DETAILS")
                DetailRow(title: "System:", value: pct(model.systemPct), dotColor: StatsTheme.red)
                DetailRow(title: "User:", value: pct(model.userPct), dotColor: StatsTheme.blue)
                DetailRow(title: "Idle:", value: pct(model.idlePct), dotColor: StatsTheme.gray)
                if model.efficiencyCores > 0 {
                    DetailRow(title: "Efficiency cores:", value: pct(model.efficiencyPct), dotColor: StatsTheme.teal)
                }
                if model.performanceCores > 0 {
                    DetailRow(title: "Performance cores:", value: pct(model.performancePct), dotColor: StatsTheme.purple)
                }
                DetailRow(title: "Uptime:", value: model.uptime)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "AVERAGE LOAD")
                DetailRow(title: "1 minute:", value: String(format: "%.2f", model.load1))
                DetailRow(title: "5 minutes:", value: String(format: "%.2f", model.load5))
                DetailRow(title: "15 minutes:", value: String(format: "%.2f", model.load15))
            }

            if model.freqAllMHz > 0 || model.freqEfficiencyMHz > 0 || model.freqPerformanceMHz > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "FREQUENCY")
                    if model.freqAllMHz > 0 {
                        DetailRow(title: "All cores:", value: "\(model.freqAllMHz) MHz")
                    }
                    if model.freqEfficiencyMHz > 0 {
                        DetailRow(
                            title: "Efficiency cores:",
                            value: "\(model.freqEfficiencyMHz) MHz",
                            dotColor: StatsTheme.teal
                        )
                    }
                    if model.freqPerformanceMHz > 0 {
                        DetailRow(
                            title: "Performance cores:",
                            value: "\(model.freqPerformanceMHz) MHz",
                            dotColor: StatsTheme.purple
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "TOP PROCESSES")
                card {
                    ProcessList(procs: model.cpuTop, showCpu: true, onCopy: { model.toast($0) })
                }
            }
        }
    }

    private var ramContent: some View {
        let usedFraction = model.memTotal > 0 ? Double(model.memUsed) / Double(model.memTotal) : 0
        return VStack(alignment: .leading, spacing: 16) {
            Button {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                )
            } label: {
                Text("Open Activity Monitor")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack(alignment: .top, spacing: 18) {
                PressureGauge(fraction: usedFraction)
                    .frame(width: 96, height: 78)
                SegmentedRing(
                    segments: [
                        (Double(model.memApp) / Double(model.memTotal), StatsTheme.blue),
                        (Double(model.memWired) / Double(model.memTotal), StatsTheme.orange),
                        (Double(model.memCompressed) / Double(model.memTotal), StatsTheme.pink)
                    ],
                    centerText: pct(usedFraction * 100),
                    size: 76,
                    lineWidth: 8
                )
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "USAGE HISTORY")
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

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "DETAILS")
                DetailRow(title: "Used:", value: MemoryFormatter.format(bytes: model.memUsed))
                stackedMemoryBar(total: Double(model.memTotal))
                DetailRow(title: "App:", value: MemoryFormatter.format(bytes: model.memApp), dotColor: StatsTheme.blue)
                DetailRow(title: "Wired:", value: MemoryFormatter.format(bytes: model.memWired), dotColor: StatsTheme.orange)
                DetailRow(
                    title: "Compressed:",
                    value: MemoryFormatter.format(bytes: model.memCompressed),
                    dotColor: StatsTheme.pink
                )
                DetailRow(title: "Free:", value: MemoryFormatter.format(bytes: model.memFree), dotColor: StatsTheme.gray)
                DetailRow(
                    title: "Swap:",
                    value: model.swapUsed > 0 ? MemoryFormatter.format(bytes: model.swapUsed) : "None",
                    dotColor: StatsTheme.yellow
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "TOP PROCESSES")
                card {
                    ProcessList(procs: model.memTop, showCpu: false, onCopy: { model.toast($0) })
                }
            }
        }
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
    private var frontmostAtShow: NSRunningApplication?

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle(from button: NSStatusBarButton) {
        if isVisible {
            close()
        } else {
            if Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                return
            }
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        StatusItemController.shared?.closePopover()

        let model = self.model ?? StatsDetailModel()
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
        var originX = buttonScreenRect.midX - size.width / 2
        if let screen = buttonWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4,
                          min(originX, screen.visibleFrame.maxX - size.width - 4))
        }

        let originY = buttonScreenRect.minY - size.height - 2
        model.arrowX = buttonScreenRect.midX - originX
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.invalidateShadow()

        if resignObserver == nil {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: win,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.close()
                }
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
        window?.orderOut(nil)
        model?.stop()
        heightObserver = nil
        removeMonitors()
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
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
