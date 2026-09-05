import AppKit

/// Locates bundled artwork. Inside the .app it lives in Contents/Resources;
/// during `swift run` it falls back to the repository's Resources folder.
enum AppResources {
    /// `swift run` / `swift build` place the binary at `<repo>/.build/<config>/BatteryLonger`
    /// (or `<repo>/.build/<triple>/<config>/…`); walk up until a `Resources` folder appears.
    /// Deliberately avoids `#filePath` so no developer path is baked into the binary.
    private static let repositoryResources: URL? = {
        guard var dir = Bundle.main.executableURL?.deletingLastPathComponent() else { return nil }
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("Resources")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue,
               FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Onboarding").path) {
                return candidate
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }()

    static func url(_ relativePath: String) -> URL? {
        if let base = Bundle.main.resourceURL {
            let candidate = base.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        guard let fallback = repositoryResources?.appendingPathComponent(relativePath) else { return nil }
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static func image(_ relativePath: String) -> NSImage? {
        guard let url = url(relativePath) else { return nil }
        return NSImage(contentsOf: url)
    }
}
