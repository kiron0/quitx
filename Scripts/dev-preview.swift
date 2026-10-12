import Foundation

let usage = """
Usage: dev-preview {welcome|cpu|memory|stats-cpu|stats-memory|stats-battery|popover|settings}
"""

let allowed = [
    "welcome", "cpu", "memory",
    "stats-cpu", "stats-memory", "stats-battery",
    "popover", "settings"
]

guard let action = CommandLine.arguments.dropFirst().first, allowed.contains(action) else {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(1)
}

DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("io.coreify.quitx.devPreview"),
    object: nil,
    userInfo: ["action": action],
    deliverImmediately: true
)
print("Requested preview: \(action) (QuitX must be running)")
