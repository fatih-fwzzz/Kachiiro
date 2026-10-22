/// One conjugated result: the primary written form and every string that counts as correct.
public struct Conjugation: Sendable, Equatable {
    public let display: String
    public let accepted: [String]

    /// `accepted` is de-duplicated, keeps order, and always contains `display` (first).
    public init(display: String, accepted: [String]) {
        self.display = display
        var seen: Set<String> = [display]
        var all = [display]
        for a in accepted where !a.isEmpty && seen.insert(a).inserted { all.append(a) }
        self.accepted = all
    }

    /// Builds from the results computed on the headword and on the reading (primary first in each).
    static func combine(headword: [String], reading: [String]) -> Conjugation? {
        guard let display = headword.first ?? reading.first else { return nil }
        return Conjugation(display: display, accepted: headword + reading)
    }

    /// Applies `transform` to display and to every accepted string; dropped strings are removed.
    func map(_ transform: (String) -> String?) -> Conjugation? {
        guard let d = transform(display) else { return nil }
        return Conjugation(display: d, accepted: accepted.compactMap(transform))
    }
}
