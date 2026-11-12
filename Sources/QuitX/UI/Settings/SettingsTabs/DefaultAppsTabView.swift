import AppKit
import SwiftUI

struct DefaultAppsTabView: View {
    @ObservedObject private var model = DefaultAppsModel.shared

    private static let segments: [QuitXSegment<DefaultAppsModel.Mode>] = [
        QuitXSegment(value: .categories, title: DefaultAppsModel.Mode.categories.rawValue, symbol: "square.grid.2x2"),
        QuitXSegment(value: .byApp, title: DefaultAppsModel.Mode.byApp.rawValue, symbol: "app"),
        QuitXSegment(value: .custom, title: DefaultAppsModel.Mode.custom.rawValue, symbol: "plus.square.on.square"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuitXSegmentedControl(segments: Self.segments, selection: $model.mode, height: 24)

            if let message = model.message {
                DefaultAppsMessageBanner(message: message) { model.message = nil }
            }

            switch model.mode {
            case .categories: DefaultAppsCategoriesView(model: model)
            case .byApp: DefaultAppsByAppView(model: model)
            case .custom: DefaultAppsCustomView(model: model)
            }
        }
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        .onAppear { model.loadIfNeeded() }
    }
}

private struct DefaultAppsMessageBanner: View {
    let message: DefaultAppsMessage
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(message.isError ? Color.orange : Color.green)
                .accessibilityHidden(true)
            Text(message.text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(10)
        .background((message.isError ? Color.orange : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((message.isError ? Color.orange : Color.green).opacity(0.25), lineWidth: 0.5)
        )
    }
}

private struct DefaultAppsCategoriesView: View {
    @ObservedObject var model: DefaultAppsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsInlineNote(
                symbol: "checklist",
                title: "One place for every default app",
                detail: "Pick an app for a whole category, or open a category to choose per file type. Changes go straight to macOS Launch Services."
            )

            if !model.hasLoaded {
                DefaultAppsLoadingRow(text: "Reading default apps from macOS…")
            } else {
                ForEach(model.categories) { category in
                    DefaultAppsCategoryCard(model: model, category: category)
                }
            }
        }
    }
}

private struct DefaultAppsCategoryCard: View {
    @ObservedObject var model: DefaultAppsModel
    let category: DefaultAppCategory

    private var isExpanded: Bool { model.expandedCategories.contains(category.id) }
    private var isBusy: Bool { category.targets.contains { model.busyTargets.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                Divider().opacity(0.5)
                VStack(spacing: 0) {
                    ForEach(category.targets) { target in
                        DefaultAppTargetRow(model: model, target: target)
                        if target != category.targets.last {
                            Divider().opacity(0.35).padding(.leading, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var header: some View {
        let summary = model.summary(for: category)
        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if isExpanded {
                        model.expandedCategories.remove(category.id)
                    } else {
                        model.expandedCategories.insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: category.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(QuitXTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(QuitXTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("\(category.detail) \(category.targets.count) \(category.targets.count == 1 ? "type" : "types").")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.title), \(isExpanded ? "collapse" : "expand")")

            if isBusy {
                ProgressView().controlSize(.small)
            }

            DefaultAppsPickerMenu(
                model: model,
                targets: category.targets,
                current: summary.app,
                isMixed: summary.isMixed,
                name: category.title
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct DefaultAppTargetRow: View {
    @ObservedObject var model: DefaultAppsModel
    let target: DefaultAppTarget
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(target.title)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Text(target.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .help(target.subtitle)

            Spacer(minLength: 8)

            if model.busyTargets.contains(target.id) {
                ProgressView().controlSize(.small)
            }

            DefaultAppsPickerMenu(
                model: model,
                targets: [target],
                current: model.entry(for: target)?.current,
                isMixed: false
            )

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Remove \(target.title) from this list. The default app stays as it is.")
                .accessibilityLabel("Remove \(target.title)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct DefaultAppsPickerMenu: View {
    @ObservedObject var model: DefaultAppsModel
    let targets: [DefaultAppTarget]
    let current: HandlerApp?
    let isMixed: Bool
    var width: CGFloat = 170
    var name: String? = nil

    private var isBusy: Bool { targets.contains { model.busyTargets.contains($0.id) } }
    private var isLoaded: Bool { targets.contains { model.entry(for: $0) != nil } }

    private var chooserTitle: String {
        if let name { return "Choose an App for \(name)" }
        if targets.count == 1, let target = targets.first { return "Choose an App for \(target.title)" }
        return "Choose an App for \(targets.count) Types"
    }

    private var chooserSubtitle: String {
        if targets.count == 1, let target = targets.first { return target.subtitle }
        let titles = targets.map(\.title)
        let shown = titles.prefix(6).joined(separator: ", ")
        return titles.count > 6 ? "\(shown) and \(titles.count - 6) more" : shown
    }

    var body: some View {
        DefaultAppsMenuButton(model: model, entries: menuEntries) {
            HStack(spacing: 6) {
                if let current, !isMixed {
                    AppIconView(bundleId: current.bundleID, url: current.url, size: 16, cornerRadius: 3)
                } else {
                    Image(systemName: isMixed ? "square.stack.3d.up" : "questionmark.app.dashed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(width: width, height: 26)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .fixedSize()
        .disabled(isBusy || !isLoaded)
        .help(helpText)
        .accessibilityLabel("Default app: \(title)")
    }

    private var title: String {
        if isMixed, let current { return "\(current.name) + others" }
        return current?.name ?? "No default"
    }

    private var helpText: String {
        if targets.count == 1, let target = targets.first {
            return "Choose the app that opens \(target.title)."
        }
        return "Choose one app for all \(targets.count) types."
    }

    private func menuEntries() -> [DefaultAppsMenuEntry] {
        let choices = model.choices(for: targets)
        var entries: [DefaultAppsMenuEntry] = []
        if choices.isEmpty {
            entries.append(.note("No apps found for this type"))
        }
        for choice in choices {
            let isCurrent = !isMixed && choice.app.matches(current)
            entries.append(.app(choice.app, title: label(for: choice), isCurrent: isCurrent) { [model, targets] in
                if !isCurrent { model.setDefault(choice.app, for: targets) }
            })
        }
        entries.append(.separator)
        entries.append(.action(title: "Other App…", symbol: "folder") { [model, targets, current, chooserTitle, chooserSubtitle] in
            model.chooseApp(for: targets, current: current, title: chooserTitle, subtitle: chooserSubtitle) { app in
                model.setDefault(app, for: targets)
            }
        })
        if let current {
            entries.append(.action(title: "Show \(current.name) in Finder", symbol: "magnifyingglass") {
                NSWorkspace.shared.activateFileViewerSelecting([current.url])
            })
        }
        return entries
    }

    private func label(for choice: (app: HandlerApp, count: Int)) -> String {
        var text = choice.app.name
        if targets.count > 1, choice.count < targets.count {
            text += " (\(choice.count) of \(targets.count))"
        }
        return text
    }
}

private struct DefaultAppsByAppView: View {
    @ObservedObject var model: DefaultAppsModel

    private var ownedTargets: [DefaultAppTarget] {
        guard let app = model.selectedApp else { return [] }
        return model.selectedAppTargets.filter { model.entry(for: $0)?.current?.matches(app) == true }
    }

    private var otherTargets: [DefaultAppTarget] {
        guard let app = model.selectedApp else { return [] }
        return model.selectedAppTargets.filter { model.entry(for: $0)?.current?.matches(app) != true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsInlineNote(
                symbol: "app.badge.checkmark",
                title: "Set defaults by app",
                detail: "Pick an app to see every file type and link it can open, then make it the default for any or all of them."
            )

            HStack(spacing: 10) {
                DefaultAppsMenuButton(model: model, entries: appEntries) {
                    HStack(spacing: 6) {
                        if let app = model.selectedApp {
                            AppIconView(bundleId: app.bundleID, url: app.url, size: 16, cornerRadius: 3)
                        }
                        Text(model.selectedApp?.name ?? "Choose an App")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                    .contentShape(Rectangle())
                }
                .fixedSize()
                .accessibilityLabel("Choose an app")

                Button("Browse…") {
                    openChooser()
                }
                .buttonStyle(UninstallSecondaryButtonStyle())

                Spacer(minLength: 0)
            }

            if let app = model.selectedApp {
                appHeader(app)

                if model.isLoadingSelectedApp {
                    DefaultAppsLoadingRow(text: "Reading what \(app.name) can open…")
                } else if model.selectedAppTargets.isEmpty {
                    DefaultAppsEmptyRow(text: "\(app.name) doesn't declare any file types or links it can open.")
                } else {
                    if !otherTargets.isEmpty {
                        targetSection(title: "Opened by Other Apps", symbol: "arrow.triangle.swap", targets: otherTargets)
                    }
                    if !ownedTargets.isEmpty {
                        targetSection(title: "Already Opened by \(app.name)", symbol: "checkmark.circle", targets: ownedTargets)
                    }
                }
            }
        }
    }

    private func appEntries() -> [DefaultAppsMenuEntry] {
        var entries: [DefaultAppsMenuEntry] = []
        if model.knownApps.isEmpty {
            entries.append(.note("Loading apps…"))
        }
        for app in model.knownApps {
            entries.append(.app(app, title: app.name, isCurrent: app.matches(model.selectedApp)) { [model] in
                model.selectApp(app)
            })
        }
        entries.append(.separator)
        entries.append(.action(title: "Other App…", symbol: "folder") { [model] in
            model.chooseApp(
                for: [],
                current: model.selectedApp,
                title: "Choose an App",
                subtitle: "See every file type and link it can open",
                confirmTitle: "Select",
                onChoose: { model.selectApp($0) }
            )
        })
        return entries
    }

    private func openChooser() {
        model.chooseApp(
            for: [],
            current: model.selectedApp,
            title: "Choose an App",
            subtitle: "See every file type and link it can open",
            confirmTitle: "Select",
            onChoose: { [model] in model.selectApp($0) }
        )
    }

    private func appHeader(_ app: HandlerApp) -> some View {
        HStack(spacing: 12) {
            AppIconView(bundleId: app.bundleID, url: app.url, size: 40, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(app.url.path)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !model.isLoadingSelectedApp, !model.selectedAppTargets.isEmpty {
                    Text("Default for \(ownedTargets.count) of \(model.selectedAppTargets.count)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(QuitXTheme.accent)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 8)
            Button("Make Default for All") {
                model.setDefault(app, for: otherTargets)
            }
            .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: !otherTargets.isEmpty && !model.isBusy))
            .disabled(otherTargets.isEmpty || model.isBusy || model.isLoadingSelectedApp)
            .help("Make \(app.name) open every type in the list below.")
        }
        .padding(12)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func targetSection(title: String, symbol: String, targets: [DefaultAppTarget]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: "\(title) (\(targets.count))", symbol: symbol)
            DefaultAppsTargetList(model: model, targets: targets)
        }
    }
}

private struct DefaultAppsTargetList: View {
    @ObservedObject var model: DefaultAppsModel
    let targets: [DefaultAppTarget]
    var onRemove: ((DefaultAppTarget) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(targets) { target in
                DefaultAppTargetRow(model: model, target: target, onRemove: onRemove.map { remove in { remove(target) } })
                if target != targets.last {
                    Divider().opacity(0.35).padding(.leading, 12)
                }
            }
        }
        .padding(.vertical, 4)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private struct DefaultAppsCustomView: View {
    @ObservedObject var model: DefaultAppsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsInlineNote(
                symbol: "plus.app",
                title: "Add any file type or link",
                detail: "Type an extension like .ts, a link scheme like vscode: or slack:, or a type identifier like public.json."
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    inputField
                    Button(addTitle, action: add)
                        .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: model.addableInputCount > 0))
                        .disabled(model.addableInputCount == 0)
                        .help(addHelp)
                }

                if model.inputChecks.isEmpty {
                    examples
                } else {
                    VStack(spacing: 6) {
                        ForEach(model.inputChecks) { check in
                            DefaultAppInputCheckRow(model: model, check: check)
                        }
                    }
                    if model.inputChecks.count > 1 {
                        Text(summaryText)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.inputChecks)

            if model.customTargets.isEmpty {
                DefaultAppsEmptyRow(text: "Nothing added yet. Added types stay here so you can change them later.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "Your Types (\(model.customTargets.count))", symbol: "list.bullet")
                    DefaultAppsTargetList(model: model, targets: model.customTargets) { target in
                        model.removeCustom(target)
                    }
                }
            }

            Text("An extension can belong to more than one type. For example, .ts is both TypeScript and MPEG-2 video, so the app you pick opens both.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var level: DefaultAppInputCheck.Level? {
        if model.inputChecks.isEmpty { return nil }
        if model.hasInputErrors { return .error }
        if model.inputChecks.contains(where: { $0.level == .warning }) { return .warning }
        return .ok
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: level?.symbol ?? "plus.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(level?.color ?? Color.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            TextField(
                "File extension, link scheme or type identifier",
                text: $model.customInput,
                prompt: Text(".ts, vscode:, public.json")
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: .monospaced))
            .onSubmit(add)
            .disableInitialFocus()

            if !model.customInput.isEmpty {
                Button {
                    model.customInput = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .accessibilityLabel("Clear")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 30)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(level.map { $0.color.opacity(0.65) } ?? Color.primary.opacity(0.14), lineWidth: level == nil ? 0.5 : 1)
        )
    }

    private var examples: some View {
        let available = DefaultAppsModel.inputExamples.filter { model.isExampleAvailable($0) }.prefix(6)
        return HStack(spacing: 6) {
            Text("Try")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(Array(available), id: \.self) { example in
                Button {
                    model.appendExample(example)
                } label: {
                    Text(example)
                        .font(.system(size: 10.5, design: .monospaced))
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Add \(example) to the field")
            }
            Spacer(minLength: 0)
            Text("Separate several with commas")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
    }

    private var addTitle: String {
        let count = model.addableInputCount
        return count > 1 ? "Add \(count)" : "Add"
    }

    private var addHelp: String {
        if model.inputChecks.isEmpty { return "Type something to add." }
        if model.addableInputCount == 0 { return "Fix the highlighted entries first." }
        if model.hasInputErrors { return "Adds the entries marked ready. The others stay in the field." }
        return "Add to your list."
    }

    private var summaryText: String {
        let ready = model.addableInputCount
        let broken = model.inputChecks.count - ready
        if broken == 0 { return "\(ready) ready to add" }
        return "\(ready) ready, \(broken) \(broken == 1 ? "needs" : "need") a fix"
    }

    private func add() {
        guard model.addableInputCount > 0 else { return }
        model.addCustomFromInput()
    }
}

private extension DefaultAppInputCheck.Level {
    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

private struct DefaultAppInputCheckRow: View {
    @ObservedObject var model: DefaultAppsModel
    let check: DefaultAppInputCheck

    private var kind: String? {
        switch check.target {
        case .fileExtension: return "Extension"
        case .urlScheme: return "Link"
        case .contentType: return "Type"
        case nil: return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: check.level.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(check.level.color)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(check.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let kind {
                        Text(kind)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                }
                Text(check.detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(check.level == .error ? check.level.color : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if check.canAdd, let target = check.target {
                    handlerLine(model.inputHandlers[target.id])
                }
            }

            Spacer(minLength: 6)

            if let suggestion = check.suggestion {
                Button("Use \(suggestion)") {
                    model.applySuggestion(check)
                }
                .buttonStyle(UninstallSecondaryButtonStyle())
                .help("Replace \u{201C}\(check.token)\u{201D} with \(suggestion)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(check.level.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(check.level.color.opacity(0.22), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func handlerLine(_ info: DefaultAppInputHandlers?) -> some View {
        if let info {
            HStack(spacing: 5) {
                if let current = info.current {
                    Text("Opens in")
                    AppIconView(bundleId: current.bundleID, url: current.url, size: 13, cornerRadius: 3)
                    Text(current.name).fontWeight(.medium)
                    if info.count > 1 {
                        Text("now, \(info.count) apps can open it")
                    } else {
                        Text("now")
                    }
                } else if info.count > 0 {
                    Text("No default yet, \(info.count) \(info.count == 1 ? "app" : "apps") can open it")
                } else {
                    Image(systemName: "info.circle")
                    Text("No installed app opens this yet. Pick one with Other App… after adding.")
                }
            }
            .font(.system(size: 10.5))
            .foregroundStyle(info.current == nil && info.count == 0 ? Color.orange : Color.secondary)
            .lineLimit(1)
        } else {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Checking apps…")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
    }
}

private struct DefaultAppsLoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DefaultAppsEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
