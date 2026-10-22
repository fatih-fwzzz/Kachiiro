import Foundation

@MainActor
public protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var rate: Float { get set }
    func load(fileName: String) throws
    func play()
    func pause()
    func seek(to: TimeInterval)
}
