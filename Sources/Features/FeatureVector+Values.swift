extension FeatureVector {

    /// The number of features in the canonical vector (Version 1).
    public static let dimension = 10

    /// The ten features as an ordered array, in the canonical order defined by
    /// `DATA_MODELS` §6.6. This is the vector operated on by the statistical
    /// model (mean, covariance, Mahalanobis distance).
    public var values: [Double] {
        [
            peakAmplitude,
            rmsEnergy,
            spectralCentroid,
            spectralBandwidth,
            spectralRollOff,
            dominantFrequency,
            zeroCrossingRate,
            attackTime,
            decayTime,
            signalDuration,
        ]
    }
}
