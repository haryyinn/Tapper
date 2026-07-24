/// The physical region of the laptop chassis associated with a tap
/// (`DATA_MODELS` §3.9, `CALIBRATION` §4.4).
///
/// The four calibrated zones are ordered `topLeft → topRight → bottomLeft →
/// bottomRight`; ``calibratable`` exposes exactly that order, which also serves
/// as the deterministic tie-break order (`ALGORITHM` §18.11). `unknown`
/// indicates that no valid classification could be produced.
public enum InteractionZone: Sendable, Equatable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case unknown

    /// The four calibratable zones in canonical order (excludes ``unknown``).
    public static let calibratable: [InteractionZone] = [
        .topLeft, .topRight, .bottomLeft, .bottomRight,
    ]
}
