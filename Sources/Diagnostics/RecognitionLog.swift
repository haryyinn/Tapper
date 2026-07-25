import Classification
import Foundation
import os

/// A bounded, chronological history of recognition outcomes
/// (`DATA_MODELS` §11.6).
///
/// Entries are appended in the order they are observed and never modified. The
/// history is diagnostic only: it never influences recognition (§11.13).
///
/// - Note: §11.6 types the log on `RecognitionResult`, which requires a tap
///   quality score from the unimplemented Tap Quality subsystem
///   (`ALGORITHM` §20). Until that exists the log stores
///   ``Classification/ClassificationOutcome`` — everything the engine can
///   mathematically determine — rather than synthesizing a quality value. See
///   backlog BL-8.
///
/// The log never contains raw audio data (§11.6).
public final class RecognitionLog: Sendable {

    /// The default number of outcomes retained.
    public static let defaultCapacity = 100

    /// The maximum number of outcomes retained.
    public let capacity: Int

    private let state = OSAllocatedUnfairLock(initialState: [ClassificationOutcome]())

    /// Creates a recognition log.
    ///
    /// - Parameter capacity: Maximum outcomes retained. Must be positive.
    public init(capacity: Int = defaultCapacity) {
        precondition(capacity > 0, "RecognitionLog capacity must be positive")
        self.capacity = capacity
    }

    /// Appends an outcome, evicting the oldest entries beyond ``capacity``.
    ///
    /// - Parameter outcome: The outcome to record.
    public func record(_ outcome: ClassificationOutcome) {
        state.withLock { entries in
            entries.append(outcome)
            if entries.count > capacity {
                entries.removeFirst(entries.count - capacity)
            }
        }
    }

    /// A snapshot of the retained outcomes, oldest first.
    public var entries: [ClassificationOutcome] {
        state.withLock { $0 }
    }

    /// The number of retained outcomes.
    public var count: Int {
        state.withLock { $0.count }
    }

    /// Removes all retained outcomes.
    public func removeAll() {
        state.withLock { $0.removeAll() }
    }
}
