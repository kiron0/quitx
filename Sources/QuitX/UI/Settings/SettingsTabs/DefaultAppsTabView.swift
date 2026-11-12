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
                isMixed: summary.isMixed
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

    private var isBusy: Bool { targets.contains { model.busyTargets.contains($0.id) } }
    private var isLoaded: Bool { targets.contains { model.entry(for: $0) != nil } }

    var body: some View {
        Menu {
            let choices = model.choices(for: targets)
            if choices.isEmpty {
                Text("No apps found for this type")
            }
            ForEach(choices, id: \.app.id) { choice in
                Button(label(for: choice)) {
                    model.setDefault(choice.app, for: targets)
                }
            }
            Divider()
            Button("Other App…") {
                if let app = model.chooseOtherApp() {
                    model.setDefault(app, for: targets)
                }
            }
            if let current {
                Button("Show \(current.name) in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([current.url])
                }
            }
        } label: {
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
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
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

    private func label(for choice: (app: HandlerApp, count: Int)) -> String {
        let isCurrent = !isMixed && choice.app.matches(current)
        var text = choice.app.name
        if targets.count > 1, choice.count < targets.count {
            text += " (\(choice.count) of \(targets.count))"
        }
        return isCurrent ? "✓ \(text)" : text
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
                Menu {
                    if model.knownApps.isEmpty {
                        Text("Loading apps…")
                    }
                    ForEach(model.knownApps) { app in
                        Button(app.name) { model.selectApp(app) }
                    }
                    Divider()
                    Button("Other App…") {
                        if let app = model.chooseOtherApp(prompt: "Select") { model.selectApp(app) }
                    }
                } label: {
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
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Choose an app")

                Button("Browse…") {
                    if let app = model.chooseOtherApp(prompt: "Select") { model.selectApp(app) }
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

            HStack(spacing: 8) {
                TextField(".ts, vscode:, public.json", text: $model.customInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit(add)
                    .disableInitialFocus()
                    .accessibilityLabel("File extension, link scheme or type identifier")
                Button("Add", action: add)
                    .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: !trimmed.isEmpty))
                    .disabled(trimmed.isEmpty)
            }

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

    private var trimmed: String {
        model.customInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        if model.addCustom(trimmed) { model.customInput = "" }
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
