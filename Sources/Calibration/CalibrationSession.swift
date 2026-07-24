import Features
import Foundation

/// The observable state of a calibration session (`CALIBRATION` §3).
///
/// A headless condensation of the §3 state machine: per-sample validation and
/// statistics steps happen inside ``CalibrationSession/addSample(_:)``.
public enum CalibrationState: Sendable, Equatable {

    /// No calibration in progress.
    case idle

    /// Collecting samples for `zone`; `accepted` samples accepted so far.
    case collecting(zone: InteractionZone, accepted: Int)

    /// All zones have their samples; ready to generate the profile.
    case readyToGenerate

    /// A profile was generated successfully.
    case completed

    /// Calibration failed.
    case failed(CalibrationError)
}

/// The result of offering a sample to a calibration session.
public enum SampleAcceptance: Sendable, Equatable {

    /// The sample was accepted for `zone`; `acceptedInZone` now collected there.
    case accepted(zone: InteractionZone, acceptedInZone: Int)

    /// The sample's feature vector failed validation and was not collected.
    case rejectedInvalidFeatureVector

    /// The session is not currently collecting samples.
    case notCollecting
}

/// A deterministic, headless calibration workflow (`CALIBRATION` §3, §9).
///
/// Collects accepted feature vectors zone by zone in canonical order, then
/// generates an immutable ``CalibrationProfile``: a single global normalization
/// transform over all accepted samples, followed by per-zone statistical model
/// generation. UI is layered on top later; this engine is fully driveable in
/// tests and produces deterministic results.
public struct CalibrationSession {

    /// The current session state.
    public private(set) var state: CalibrationState = .idle

    private let configuration: CalibrationConfiguration
    private let deviceIdentifier: String
    private let algorithmVersion: String
    private var samplesByZone: [InteractionZone: [[Double]]] = [:]

    /// Creates a calibration session.
    ///
    /// - Parameters:
    ///   - configuration: The statistical configuration.
    ///   - deviceIdentifier: A device fingerprint recorded in the profile.
    ///   - algorithmVersion: The algorithm version recorded in the profile.
    public init(
        configuration: CalibrationConfiguration = .v1,
        deviceIdentifier: String,
        algorithmVersion: String
    ) {
        self.configuration = configuration
        self.deviceIdentifier = deviceIdentifier
        self.algorithmVersion = algorithmVersion
    }

    /// Starts collection at the first canonical zone.
    public mutating func begin() {
        guard case .idle = state else { return }
        samplesByZone = [:]
        state = .collecting(zone: InteractionZone.calibratable[0], accepted: 0)
    }

    /// Offers a sample to the session.
    ///
    /// Invalid feature vectors are rejected and not collected. Once the current
    /// zone reaches ``CalibrationConfiguration/samplesPerZone``, collection
    /// advances to the next zone, or to ``CalibrationState/readyToGenerate``
    /// after the last zone.
    ///
    /// - Parameter vector: The candidate feature vector.
    /// - Returns: Whether the sample was accepted.
    public mutating func addSample(_ vector: FeatureVector) -> SampleAcceptance {
        guard case .collecting(let zone, let accepted) = state else { return .notCollecting }
        guard vector.isValid else { return .rejectedInvalidFeatureVector }

        samplesByZone[zone, default: []].append(vector.values)
        let acceptedInZone = accepted + 1

        if acceptedInZone >= configuration.samplesPerZone {
            if let next = nextZone(after: zone) {
                state = .collecting(zone: next, accepted: 0)
            } else {
                state = .readyToGenerate
            }
        } else {
            state = .collecting(zone: zone, accepted: acceptedInZone)
        }
        return .accepted(zone: zone, acceptedInZone: acceptedInZone)
    }

    /// Generates the calibration profile from the collected samples.
    ///
    /// Valid only in the ``CalibrationState/readyToGenerate`` state. Computes one
    /// global normalization transform over all accepted samples, then generates
    /// each zone profile. On any zone failure the session enters
    /// ``CalibrationState/failed(_:)``.
    ///
    /// - Parameters:
    ///   - createdAt: The profile creation timestamp.
    ///   - id: The profile identifier. Defaults to a fresh `UUID`.
    /// - Returns: The generated immutable profile, or a ``CalibrationError``.
    public mutating func generateProfile(
        createdAt: Date,
        id: UUID = UUID()
    ) -> Result<CalibrationProfile, CalibrationError> {
        guard case .readyToGenerate = state else { return .failure(.emptyDataset) }

        let allSamples = InteractionZone.calibratable.flatMap { samplesByZone[$0] ?? [] }
        let normalization = NormalizationParameters.compute(from: allSamples)

        var zoneProfiles: [ZoneProfile] = []
        for zone in InteractionZone.calibratable {
            let normalizedSamples = (samplesByZone[zone] ?? []).map { normalization.normalize($0) }
            switch ZoneProfileGenerator.generate(
                zone: zone, normalizedSamples: normalizedSamples, configuration: configuration)
            {
            case .success(let profile):
                zoneProfiles.append(profile)
            case .failure(let error):
                state = .failed(error)
                return .failure(error)
            }
        }

        let profile = CalibrationProfile(
            id: id,
            algorithmVersion: algorithmVersion,
            deviceIdentifier: deviceIdentifier,
            createdAt: createdAt,
            zones: zoneProfiles,
            normalization: normalization,
            configuration: configuration
        )
        state = .completed
        return .success(profile)
    }

    private func nextZone(after zone: InteractionZone) -> InteractionZone? {
        guard
            let index = InteractionZone.calibratable.firstIndex(of: zone),
            index + 1 < InteractionZone.calibratable.count
        else { return nil }
        return InteractionZone.calibratable[index + 1]
    }
}
