import Foundation
import os

/// A bounded, append-only, in-memory store of diagnostic records
/// (`DATA_MODELS` §11.11).
///
/// Records may be produced concurrently by several subsystems, so insertion is
/// synchronized. The log is append-only: existing records are never modified,
/// and once the capacity is reached the oldest records are evicted so memory
/// stays bounded (the documented "Diagnostics Buffer Size", `ALGORITHM` §27.9,
/// defaults to 100 events).
///
/// Invalid records are discarded rather than propagated (§11.10), and recording
/// never throws — a diagnostics failure must never surface in the observed
/// subsystem.
public final class DiagnosticsLog: Sendable {

    /// The documented default capacity in records (`ALGORITHM` §27.9).
    public static let defaultCapacity = 100

    /// The maximum number of records retained.
    public let capacity: Int

    private let state = OSAllocatedUnfairLock(initialState: [DiagnosticsRecord]())

    /// Creates a diagnostics log.
    ///
    /// - Parameter capacity: Maximum records retained. Must be positive.
    ///   Defaults to ``defaultCapacity``.
    public init(capacity: Int = defaultCapacity) {
        precondition(capacity > 0, "DiagnosticsLog capacity must be positive")
        self.capacity = capacity
    }

    /// Appends a record, discarding it if invalid.
    ///
    /// - Parameter record: The record to append.
    /// - Returns: `true` if the record was retained; `false` if it was discarded
    ///   as invalid. The result is informational — callers are not required to
    ///   act on it.
    @discardableResult
    public func record(_ record: DiagnosticsRecord) -> Bool {
        guard record.isValid else { return false }
        state.withLock { records in
            records.append(record)
            if records.count > capacity {
                records.removeFirst(records.count - capacity)
            }
        }
        return true
    }

    /// A snapshot of the retained records, oldest first.
    public var records: [DiagnosticsRecord] {
        state.withLock { $0 }
    }

    /// The number of retained records.
    public var count: Int {
        state.withLock { $0.count }
    }

    /// Removes all retained records.
    ///
    /// Clearing discards the in-memory buffer; it does not alter any previously
    /// exported bundle.
    public func removeAll() {
        state.withLock { $0.removeAll() }
    }
}
