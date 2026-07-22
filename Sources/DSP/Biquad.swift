/// A second-order IIR section (biquad) with `a0` normalized to 1.
///
/// Filtering uses the Direct Form II Transposed structure and processes a buffer
/// from zero initial state, so each analysis window is filtered independently
/// and deterministically.
struct Biquad: Equatable {

    let b0: Double
    let b1: Double
    let b2: Double
    let a1: Double
    let a2: Double

    /// Filters a signal, starting from zero state.
    ///
    /// - Parameter input: The input samples.
    /// - Returns: The filtered samples, same length as the input.
    func filtered(_ input: [Double]) -> [Double] {
        var state1 = 0.0
        var state2 = 0.0
        var output = [Double](repeating: 0, count: input.count)
        for index in input.indices {
            let sample = input[index]
            let result = b0 * sample + state1
            state1 = b1 * sample - a1 * result + state2
            state2 = b2 * sample - a2 * result
            output[index] = result
        }
        return output
    }
}
