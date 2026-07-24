/// Generates a zone's ``ZoneProfile`` from its normalized calibration samples
/// (`ALGORITHM` §16.11–16.16, `CALIBRATION` §7, §9).
///
/// The pipeline is deterministic: build an initial regularized model, reject
/// outliers in a single `mean + k·σ` Mahalanobis pass, enforce the retained-set
/// floor, then recompute the final mean, regularized covariance, inverse, and
/// acceptance threshold over the retained samples. Samples are expected to be
/// already normalized by the global transform.
public enum ZoneProfileGenerator {

    /// Generates a zone profile.
    ///
    /// - Parameters:
    ///   - zone: The zone being calibrated.
    ///   - normalizedSamples: The zone's accepted samples, globally normalized,
    ///     canonical order.
    ///   - configuration: The statistical configuration.
    /// - Returns: The generated ``ZoneProfile`` or a ``CalibrationError``.
    public static func generate(
        zone: InteractionZone,
        normalizedSamples: [[Double]],
        configuration: CalibrationConfiguration
    ) -> Result<ZoneProfile, CalibrationError> {
        guard !normalizedSamples.isEmpty else { return .failure(.emptyDataset) }

        // Initial regularized model over all samples, for outlier detection.
        let initialMean = FeatureStatistics.mean(of: normalizedSamples)
        guard
            let initialInverse = invertRegularizedCovariance(
                of: normalizedSamples, mean: initialMean, lambda: configuration.regularizationLambda
            )
        else { return .failure(.singularCovariance) }

        let initialDistances = normalizedSamples.map {
            MahalanobisDistance.distance(
                vector: $0, mean: initialMean, inverseCovariance: initialInverse)
        }
        let outlierThreshold = threshold(
            from: initialDistances, multiplier: configuration.thresholdMultiplier)

        // Single-pass outlier rejection.
        let retained = zip(normalizedSamples, initialDistances)
            .filter { $0.1 <= outlierThreshold }
            .map { $0.0 }
        guard retained.count >= configuration.minimumRetainedSamples else {
            return .failure(
                .insufficientRetainedSamples(
                    retained: retained.count, required: configuration.minimumRetainedSamples))
        }

        // Final regularized model over the retained samples.
        let finalMean = FeatureStatistics.mean(of: retained)
        let regularizedCovariance = FeatureStatistics.regularized(
            FeatureStatistics.covariance(of: retained, mean: finalMean),
            lambda: configuration.regularizationLambda)
        guard let finalInverse = LinearAlgebra.invertPositiveDefinite(regularizedCovariance) else {
            return .failure(.singularCovariance)
        }

        let finalDistances = retained.map {
            MahalanobisDistance.distance(
                vector: $0, mean: finalMean, inverseCovariance: finalInverse)
        }
        let acceptanceThreshold = threshold(
            from: finalDistances, multiplier: configuration.thresholdMultiplier)

        let profile = ZoneProfile(
            zone: zone,
            meanVector: MeanVector(values: finalMean),
            covarianceMatrix: CovarianceMatrix(values: regularizedCovariance),
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: finalInverse),
            threshold: ThresholdModel(
                acceptanceThreshold: acceptanceThreshold,
                ambiguityMargin: configuration.ambiguityMargin)
        )
        return .success(profile)
    }

    private static func invertRegularizedCovariance(
        of samples: [[Double]], mean: [Double], lambda: Double
    ) -> [[Double]]? {
        let regularized = FeatureStatistics.regularized(
            FeatureStatistics.covariance(of: samples, mean: mean), lambda: lambda)
        return LinearAlgebra.invertPositiveDefinite(regularized)
    }

    /// The `mean + multiplier·σ` threshold over a set of distances
    /// (`ALGORITHM` §17.18), using the sample standard deviation.
    private static func threshold(from distances: [Double], multiplier: Double) -> Double {
        guard !distances.isEmpty else { return 0 }
        let mean = distances.reduce(0, +) / Double(distances.count)
        guard distances.count > 1 else { return mean }
        let variance =
            distances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(distances.count - 1)
        return mean + multiplier * variance.squareRoot()
    }
}
