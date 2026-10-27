import AppKit
import SwiftUI

enum ItemSizeFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any size"
    case over10MB = "Over 10 MB"
    case over100MB = "Over 100 MB"
    case over500MB = "Over 500 MB"
    case over1GB = "Over 1 GB"
    case over10GB = "Over 10 GB"

    var id: String { rawValue }

    var minimumBytes: Int64 {
        switch self {
        case .any: return 0
        case .over10MB: return 10 * 1024 * 1024
        case .over100MB: return 100 * 1024 * 1024
        case .over500MB: return 500 * 1024 * 1024
        case .over1GB: return 1024 * 1024 * 1024
        case .over10GB: return 10 * 1024 * 1024 * 1024
        }
    }
}

enum ItemAgeFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any age"
    case week = "Older than 7d"
    case month = "Older than 30d"
    case sixMonths = "Older than 6mo"
    case year = "Older than 1yr"

    var id: String { rawValue }

    func cutoff(relativeTo now: Date = Date()) -> Date? {
        switch self {
        case .any: return nil
        case .week: return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .month: return Calendar.current.date(byAdding: .day, value: -30, to: now)
        case .sixMonths: return Calendar.current.date(byAdding: .month, value: -6, to: now)
        case .year: return Calendar.current.date(byAdding: .year, value: -1, to: now)
        }
    }
}

enum ItemSortOrder: String, CaseIterable, Identifiable, Sendable {
    case largest = "Largest first"
    case smallest = "Smallest first"
    case newest = "Newest first"
    case oldest = "Oldest first"
    case nameAsc = "Name (A–Z)"
    case nameDesc = "Name (Z–A)"

    var id: String { rawValue }
}

enum ItemFilterHelper {
    static func filterAndSort(
        items: [CleanupItem],
        query: String,
        size: ItemSizeFilter,
        age: ItemAgeFilter,
        sort: ItemSortOrder,
        now: Date = Date()
    ) -> [CleanupItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cutoff = age.cutoff(relativeTo: now)

        return items.filter { item in
            guard item.bytes >= size.minimumBytes else { return false }
            if let cutoff {
                guard let modified = item.lastModified, modified < cutoff else { return false }
            }
            guard !trimmed.isEmpty else { return true }
            return item.name.localizedCaseInsensitiveContains(trimmed)
                || item.url.path.localizedCaseInsensitiveContains(trimmed)
        }.sorted { left, right in
            switch sort {
            case .largest:
                if left.bytes != right.bytes { return left.bytes > right.bytes }
            case .smallest:
                if left.bytes != right.bytes { return left.bytes < right.bytes }
            case .newest:
                let lDate = left.lastModified ?? .distantPast
                let rDate = right.lastModified ?? .distantPast
                if lDate != rDate { return lDate > rDate }
            case .oldest:
                let lDate = left.lastModified ?? .distantFuture
                let rDate = right.lastModified ?? .distantFuture
                if lDate != rDate { return lDate < rDate }
            case .nameAsc:
                let comp = left.name.localizedStandardCompare(right.name)
                if comp != .orderedSame { return comp == .orderedAscending }
            case .nameDesc:
                let comp = left.name.localizedStandardCompare(right.name)
                if comp != .orderedSame { return comp == .orderedDescending }
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    static func filterAndSort(
        items: [LeftoverItem],
        query: String,
        size: ItemSizeFilter,
        age: ItemAgeFilter,
        sort: ItemSortOrder,
        now: Date = Date()
    ) -> [LeftoverItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cutoff = age.cutoff(relativeTo: now)

        return items.filter { item in
            guard item.bytes >= size.minimumBytes else { return false }
            if let cutoff {
                guard let modified = item.lastModified, modified < cutoff else { return false }
            }
            guard !trimmed.isEmpty else { return true }
            return item.name.localizedCaseInsensitiveContains(trimmed)
                || item.url.path.localizedCaseInsensitiveContains(trimmed)
        }.sorted { left, right in
            switch sort {
            case .largest:
                if left.bytes != right.bytes { return left.bytes > right.bytes }
            case .smallest:
                if left.bytes != right.bytes { return left.bytes < right.bytes }
            case .newest:
                let lDate = left.lastModified ?? .distantPast
                let rDate = right.lastModified ?? .distantPast
                if lDate != rDate { return lDate > rDate }
            case .oldest:
                let lDate = left.lastModified ?? .distantFuture
                let rDate = right.lastModified ?? .distantFuture
                if lDate != rDate { return lDate < rDate }
            case .nameAsc:
                let comp = left.name.localizedStandardCompare(right.name)
                if comp != .orderedSame { return comp == .orderedAscending }
            case .nameDesc:
                let comp = left.name.localizedStandardCompare(right.name)
                if comp != .orderedSame { return comp == .orderedDescending }
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }
}

struct CleanupFilterBar: View {
    @Binding var query: String
    @Binding var size: ItemSizeFilter
    @Binding var age: ItemAgeFilter
    @Binding var sort: ItemSortOrder
    let visibleCount: Int
    let totalCount: Int
    var isFiltered: Bool = false
    var onReset: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                TextField("Search name or path…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))

            HStack(spacing: 8) {
                NativeFilterPicker(selection: $size)
                NativeFilterPicker(selection: $age)
                NativeFilterPicker(selection: $sort)
            }

            HStack {
                Text("\(visibleCount) of \(totalCount) items shown")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                Spacer()

                if isFiltered, let onReset {
                    Button("Reset Filters") {
                        onReset()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(QuitXTheme.accent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
