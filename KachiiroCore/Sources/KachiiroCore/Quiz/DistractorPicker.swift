public enum DistractorPicker {
    /// Walks `tiers` in priority order; inside a tier candidates are de-duplicated and shuffled with `rng`.
    /// Never returns `correct` or any string in `accepted`. Returns `nil` when fewer than `count` exist.
    public static func pick(
        correct: String,
        accepted: [String],
        tiers: [[String]],
        count: Int = 3,
        rng: inout some RandomNumberGenerator
    ) -> [String]? {
        var excluded = Set(accepted)
        excluded.insert(correct)
        var picked: [String] = []
        for tier in tiers {
            var seen = Set<String>()
            let candidates = tier.filter { !$0.isEmpty && !excluded.contains($0) && seen.insert($0).inserted }
            for c in candidates.shuffled(using: &rng) {
                picked.append(c)
                excluded.insert(c)
                if picked.count == count { return picked }
            }
        }
        return nil
    }
}
