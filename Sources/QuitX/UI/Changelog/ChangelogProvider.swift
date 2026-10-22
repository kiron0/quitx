import Foundation

struct ChangelogSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [String]

    init(_ title: String, _ items: [String]) {
        self.id = title
        self.title = title
        self.items = items
    }
}

struct ReleaseChangelog: Identifiable, Hashable, Sendable {
    let id: String
    let version: String
    let summary: String
    let sections: [ChangelogSection]

    init(_ version: String, _ summary: String, _ sections: [(String, [String])]) {
        self.id = version
        self.version = version
        self.summary = summary
        self.sections = sections.map { ChangelogSection($0.0, $0.1) }
    }

    init(version: String, summary: String = "", sections: [ChangelogSection]) {
        self.id = version
        self.version = version
        self.summary = summary
        self.sections = sections
    }
}

enum ChangelogProvider {
    static func releases() -> [ReleaseChangelog] {
        appReleases
    }

    static func parse(markdown: String) -> [ReleaseChangelog] {
        var releases: [ReleaseChangelog] = []
        var currentVersion: String?
        var currentSectionTitle: String?
        var currentItems: [String] = []
        var currentSections: [ChangelogSection] = []

        func flushSection() {
            if let title = currentSectionTitle, !currentItems.isEmpty {
                currentSections.append(ChangelogSection(title, currentItems))
                currentItems.removeAll()
            }
            currentSectionTitle = nil
        }

        func flushRelease() {
            flushSection()
            if let version = currentVersion, !currentSections.isEmpty {
                releases.append(ReleaseChangelog(version: version, sections: currentSections))
                currentSections.removeAll()
            }
            currentVersion = nil
        }

        let lines = markdown.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                flushRelease()
                let v = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty {
                    currentVersion = v
                }
            } else if line.hasPrefix("### ") {
                flushSection()
                let s = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    currentSectionTitle = s
                }
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let item = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty {
                    currentItems.append(item)
                }
            } else if !line.isEmpty, !currentItems.isEmpty, !line.hasPrefix("#") {
                let last = currentItems.removeLast()
                currentItems.append("\(last) \(line)")
            }
        }

        flushRelease()
        return releases
    }
}
