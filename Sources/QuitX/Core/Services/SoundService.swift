import AppKit

enum SoundService {
    private static let singleSound: NSSound? = loadSound(named: "quit-single")
    private static let allSound: NSSound? = loadSound(named: "quit-all")

    static func playQuitSingle() {
        guard ConfigStore.shared.config.playSounds else { return }
        singleSound?.stop()
        singleSound?.play()
    }

    static func playQuitAll() {
        guard ConfigStore.shared.config.playSounds else { return }
        allSound?.stop()
        allSound?.play()
    }

    private static func loadSound(named name: String) -> NSSound? {
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff") {
            return NSSound(contentsOf: url, byReference: true)
        }

        let localPath = "Support/Sounds/\(name).aiff"
        if FileManager.default.fileExists(atPath: localPath) {
            return NSSound(contentsOfFile: localPath, byReference: true)
        }
        return nil
    }
}
