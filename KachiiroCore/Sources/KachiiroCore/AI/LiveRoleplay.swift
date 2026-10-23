import Foundation

/// A stateful voice partner. `reply` speaks the partner's next turn for `history` and returns its transcript.
@MainActor public protocol LiveRoleplayPartner: AnyObject {
    func reply(
        system: String, history: [RoleplayViewModel.Line], onAudio: @escaping @MainActor (Data) -> Void
    ) async throws -> String
    func close()
}

/// Plays raw 16-bit little-endian mono PCM as it streams in.
@MainActor public protocol PCMAudioStreaming: AnyObject {
    func enqueue(_ pcm16: Data, sampleRate: Double)
    func stop()
}
