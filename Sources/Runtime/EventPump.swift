import Audio
import Detection
import Foundation

/// Steps the tap detector through the ring buffer by absolute stream position
/// (`ALGORITHM` §23.2, §23.4.1).
///
/// Frames are taken at fixed hops through the stream rather than at poll time,
/// so every sample is examined exactly as often regardless of scheduling
/// jitter. When a frame detects an event, stepping pauses until the event's
/// whole window has been captured, then the event is extracted and measured.
///
/// Sequencing only: every decision belongs to ``Detection/TapDetector``.
struct EventPump {

    /// Frame length, in samples.
    let frameSize: Int

    /// Samples between consecutive frames.
    let hopSize: Int

    /// Absolute position one past the next frame to examine.
    private var nextFrameEnd: Int?

    /// An event awaiting its samples.
    private var pending: EventRequest?

    /// Creates a pump.
    init(frameSize: Int, hopSize: Int) {
        self.frameSize = frameSize
        self.hopSize = hopSize
    }

    /// Discards any pending event and resumes from `position`, so audio
    /// captured before it is never examined.
    mutating func resume(at position: Int) {
        nextFrameEnd = Swift.max(frameSize, position)
        pending = nil
    }

    /// Examines every frame and event that the buffer can now supply.
    ///
    /// - Parameters:
    ///   - buffer: The ring buffer written by the audio callback.
    ///   - detector: The tap detector.
    ///   - timestamp: The timestamp recorded on any outcome.
    /// - Returns: The outcome of each examined frame or event, in order.
    mutating func poll(
        buffer: RollingAudioBuffer, detector: inout TapDetector, at timestamp: Date
    ) -> [DetectionOutcome] {
        let written = buffer.totalSamplesWritten
        if nextFrameEnd == nil { resume(at: written) }
        var outcomes: [DetectionOutcome] = []

        while true {
            if let request = pending {
                guard written >= request.readEnd else { break }
                pending = nil
                // An event overwritten before it could be read is lost; with
                // the ring's 341 ms of history this needs a stalled worker.
                guard let raw = buffer.samples(from: request.readStart, count: request.readCount)
                else { continue }
                outcomes.append(
                    detector.measure(request, samples: raw.map(Double.init), at: timestamp))
                continue
            }

            guard let frameEnd = nextFrameEnd, frameEnd <= written else { break }
            nextFrameEnd = frameEnd + hopSize
            guard let raw = buffer.samples(from: frameEnd - frameSize, count: frameSize) else {
                // Fallen behind the ring: skip to the present.
                resume(at: written)
                continue
            }
            switch detector.detect(frame: raw.map(Double.init), startingAt: frameEnd - frameSize) {
            case .noCandidate, .continuation:
                outcomes.append(.noCandidate)
            case .event(let request):
                pending = request
            }
        }
        return outcomes
    }
}
