import SwiftUI

struct AdvancedTabView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            row(label: "Background:") {
                toggle("View background apps", isOn: Binding(
                    get: { configStore.config.includeBackground },
                    set: {
                        configStore.config.includeBackground = $0
                        AppListViewModel.shared.showBackgroundApps = $0
                        configStore.save(refreshAppList: true)
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Heads up, some background apps will immediately restart after quitting them. It’s sorcery beyond our control. 🧙‍♂️")
            }

            row(label: "") {
                toggle("Group background instances", isOn: Binding(
                    get: { configStore.config.groupBackground },
                    set: { configStore.config.groupBackground = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Stacks clone processes like pancakes so you don't scroll past 47 identical helper daemons. 🥞📚")
            }

            row(label: "Protection:") {
                toggle("Never quit music apps", isOn: Binding(
                    get: { configStore.config.neverQuitMusic },
                    set: { configStore.config.neverQuitMusic = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Don't stop believin', hold on to that feelin' — and your music! Exclude Spotify and Apple Music from auto or manual Quit actions. 🎵")
            }

            row(label: "Behavior:") {
                toggle("Select apps by default", isOn: Binding(
                    get: { configStore.config.defaultSelectAll },
                    set: {
                        configStore.config.defaultSelectAll = $0
                        configStore.save()
                        AppListViewModel.shared.applyDefaultSelection()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Tweak default app selection, rotating tips, and confirmation guardrails. You do you! 🍦🛡️")
            }

            row(label: "") {
                toggle("Disable quit tips", isOn: Binding(
                    get: { configStore.config.disableQuitTips },
                    set: { configStore.config.disableQuitTips = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "The rotating tips at the bottom of the QuitX dropdown will cease to show. It’s okay. We can still be friends. 🤗")
            }

            row(label: "") {
                toggle("Confirm single app quit & restart", isOn: Binding(
                    get: { configStore.config.confirmIndividualAction },
                    set: { configStore.config.confirmIndividualAction = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Look before you leap! Adds a friendly 'Are you sure?' safety net before kicking out individual apps. 🛡️🦺")
            }

            row(label: "Extras:") {
                toggle("Include Finder Windows in list", isOn: Binding(
                    get: { configStore.config.includeFinder },
                    set: { configStore.config.includeFinder = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Bonus cleanup powers! Close all open Finder windows or empty the Trash right alongside your apps. 📁🗑️")
            }

            row(label: "") {
                toggle("Include Empty Trash in list", isOn: Binding(
                    get: { configStore.config.includeTrash },
                    set: { configStore.config.includeTrash = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "A truly fresh start without a restart. Take out the trash at the same time you take out the apps! 🗑️🧹")
            }

            Spacer(minLength: 0)
        }
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
    }
}

