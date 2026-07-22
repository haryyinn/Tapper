/// A window function applied before frequency-domain analysis
/// (`DATA_MODELS` §5.5).
///
/// Version 1 uses only ``hann`` during runtime recognition; the other cases
/// exist for diagnostics and future compatibility.
public enum WindowFunction: Sendable, Equatable {
    case hann
    case hamming
    case blackman
    case rectangular
}
