public enum Politeness: String, Sendable, CaseIterable { case polite, plain }
public enum Tense: String, Sendable, CaseIterable { case nonPast, past }
public enum Polarity: String, Sendable, CaseIterable { case affirmative, negative }

/// One of the 8 cells of the plain/polite matrix.
public struct InflectionCell: Sendable, Hashable {
    public let politeness: Politeness
    public let tense: Tense
    public let polarity: Polarity

    public init(politeness: Politeness, tense: Tense, polarity: Polarity) {
        self.politeness = politeness
        self.tense = tense
        self.polarity = polarity
    }

    public static let all: [InflectionCell] = Politeness.allCases.flatMap { pol in
        Tense.allCases.flatMap { t in
            Polarity.allCases.map { InflectionCell(politeness: pol, tense: t, polarity: $0) }
        }
    }

    /// `{polite|plain}-{nonPast|past}-{affirmative|negative}`
    public var raw: String { "\(politeness.rawValue)-\(tense.rawValue)-\(polarity.rawValue)" }

    public init?(raw: String) {
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let pol = Politeness(rawValue: parts[0]),
              let t = Tense(rawValue: parts[1]),
              let pl = Polarity(rawValue: parts[2]) else { return nil }
        self.init(politeness: pol, tense: t, polarity: pl)
    }

    public var label: String {
        let pol = politeness == .polite ? "Polite" : "Plain"
        let t = tense == .nonPast ? "Non-past" : "Past"
        let pl = polarity == .affirmative ? "Affirmative" : "Negative"
        return "\(pol) · \(t) · \(pl)"
    }

    /// The same tense/polarity in the other register.
    public var registerSwapped: InflectionCell {
        InflectionCell(politeness: politeness == .polite ? .plain : .polite, tense: tense, polarity: polarity)
    }
}
