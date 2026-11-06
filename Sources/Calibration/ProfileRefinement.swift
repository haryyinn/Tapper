import Features
import Foundation

/// Why a profile could not be refined.
public enum RefinementError: Error, Equatable, Sendable {

    /// The profile predates ADR-015 and carries no labelled samples, so the
    /// original observations cannot be recovered and refinement would silently
    /// discard them. Re-run calibration instead.
    case profileCarriesNoSamples

    /// No additional samples were supplied.
    case noAdditionalSamples

    /// Regenerating a zone failed; the profile is unchanged.
    case generationFailed(zone: InteractionZone, error: CalibrationError)
}

/// Rebuilds a calibration profile from its stored samples plus additional
/// labelled observations (ADR-015).
///
/// This is **infrastructure only**. Nothing in Tapper calls it automatically:
/// recognition never adapts while running, and no profile is ever modified as a
/// side effect of a tap. It exists so that adding samples is a solved problem
/// when an explicit, user-initiated refinement flow is specified.
///
/// Two invariants shape the design:
///
/// - **Profiles are immutable.** Refinement returns a *new* profile and leaves
///   the original untouched, so a refinement that produces a worse model can be
///   discarded by keeping the profile already on disk.
/// - **Both recognisers stay consistent.** The whole profile is regenerated
///   through ``ZoneProfileGenerator/generate(zone:normalizedSamples:configuration:)``
///   from the combined sample set, so the statistical model, the acceptance
///   threshold, the stored samples and the neighbour radius all describe the
///   same data. Appending to the sample list alone would leave the Mahalanobis
///   model describing one dataset and k-NN another.
public enum ProfileRefinement {

    /// Regenerates a profile from its stored samples plus new ones.
    ///
    /// - Parameters:
    ///   - profile: The profile to refine. Not modified.
    ///   - additionalSamples: New labelled samples per zone, **already
    ///     normalized with `profile.normalization`**. The normalization
    ///     transform is deliberately not recomputed: stored samples are held in
    ///     normalized space, and re-deriving the transform would invalidate
    ///     them.
    ///   - createdAt: The timestamp for the regenerated profile.
    /// - Returns: A new profile, or the reason refinement was refused.
    public static func refine(
        profile: CalibrationProfile,
        addingNormalized additionalSamples: [InteractionZone: [[Double]]],
        createdAt: Date = Date()
    ) -> Result<CalibrationProfile, RefinementError> {
        guard profile.zones.allSatisfy({ !$0.samples.isEmpty }) else {
            return .failure(.profileCarriesNoSamples)
        }
        guard additionalSamples.values.contains(where: { !$0.isEmpty }) else {
            return .failure(.noAdditionalSamples)
        }

        var regenerated: [ZoneProfile] = []
        regenerated.reserveCapacity(profile.zones.count)
        for zone in profile.zones {
            let combined = zone.samples + (additionalSamples[zone.zone] ?? [])
            switch ZoneProfileGenerator.generate(
                zone: zone.zone, normalizedSamples: combined,
                configuration: profile.configuration)
            {
            case .success(let updated):
                regenerated.append(updated)
            case .failure(let error):
                return .failure(.generationFailed(zone: zone.zone, error: error))
            }
        }

        // A new identity: the result is a distinct profile, not a mutation of
        // the one it was derived from.
        return .success(
            CalibrationProfile(
                id: UUID(),
                algorithmVersion: profile.algorithmVersion,
                deviceIdentifier: profile.deviceIdentifier,
                createdAt: createdAt,
                zones: regenerated,
                normalization: profile.normalization,
                configuration: profile.configuration,
                derivedDetection: profile.derivedDetection))
    }

    /// Normalizes a feature vector with a profile's stored transform, so a
    /// newly observed tap can be offered to ``refine(profile:addingNormalized:createdAt:)``.
    ///
    /// - Parameters:
    ///   - featureVector: The observed features, in raw units.
    ///   - profile: The profile supplying the normalization transform.
    /// - Returns: The normalized sample.
    public static func normalized(
        _ featureVector: FeatureVector, for profile: CalibrationProfile
    ) -> [Double] {
        profile.normalization.normalize(featureVector.values)
    }
}
