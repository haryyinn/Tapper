import Calibration
import Foundation

/// The mathematically complete output of zone classification (`ALGORITHM` §18).
///
/// Carries exactly the values the classifier can determine from Phase 4's
/// statistical model: the recognized zone (or `unknown`), the decision
/// `status`, the best Mahalanobis `distance`, the diagnostic `confidence` (0–100,
/// `ALGORITHM` §17.19), the `acceptanceThreshold` used, and the second-best
/// distance for ambiguity diagnostics.
///
/// It deliberately does **not** include a tap quality score: that value belongs
/// to the Tap Quality subsystem (`ALGORITHM` §20), which is outside Phase 4. The
/// runtime/application layer assembles the canonical `RecognitionResult`
/// (`DATA_MODELS` §9.5) from this outcome once Tap Quality exists (see backlog).
public struct ClassificationOutcome: Sendable, Equatable {

    /// The decision status. The classifier yields `success`, `ambiguous`, or
    /// `unknown`.
    public let status: RecognitionStatus

    /// The recognized zone, or `unknown` when no valid recognition occurred.
    public let zone: InteractionZone

    /// The best (smallest) Mahalanobis distance across zones.
    public let distance: Double

    /// Diagnostic confidence in the range 0–100 (`ALGORITHM` §17.19). Never
    /// influences the decision.
    public let confidence: Double

    /// The acceptance threshold of the best zone that was applied.
    public let acceptanceThreshold: Double

    /// The second-best zone's distance, if more than one zone exists; used for
    /// ambiguity diagnostics.
    public let secondBestDistance: Double?

    /// The classification timestamp.
    public let timestamp: Date

    /// Creates a classification outcome.
    public init(
        status: RecognitionStatus,
        zone: InteractionZone,
        distance: Double,
        confidence: Double,
        acceptanceThreshold: Double,
        secondBestDistance: Double?,
        timestamp: Date
    ) {
        self.status = status
        self.zone = zone
        self.distance = distance
        self.confidence = confidence
        self.acceptanceThreshold = acceptanceThreshold
        self.secondBestDistance = secondBestDistance
        self.timestamp = timestamp
    }
}
