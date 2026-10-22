import Foundation

/// Finds the bundled lesson MP3s. Files added under `Kachiiro/Audio` are flattened into the bundle root
/// by the synchronized group (checked in the built `.app`).
enum BundleAudioIndex {
    static func fileNames(in bundle: Bundle = .main) -> [String] {
        (bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []).map(\.lastPathComponent).sorted()
    }

    static func url(for fileName: String, in bundle: Bundle = .main) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        return bundle.url(forResource: name, withExtension: "mp3")
    }
}
