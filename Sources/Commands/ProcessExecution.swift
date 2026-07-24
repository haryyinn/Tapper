import Foundation

/// Runs a configured `Process` and maps its outcome to a ``CommandResult``.
///
/// Internal helper shared by the process-based providers. Standard output and
/// error are left untouched (inherited from the parent), so they are preserved
/// exactly as produced by `Process`. Execution waits for the process to exit so
/// the exit status can be captured (`API_REFERENCE` §5).
enum ProcessExecution {

    /// Launches the process, waits for it to exit, and reports the outcome.
    ///
    /// - Parameters:
    ///   - process: A `Process` with its executable and arguments configured.
    ///   - commandID: The identifier of the command being executed.
    /// - Returns: A success result for a zero exit status, or a failure result
    ///   carrying the non-zero status or the launch failure.
    static func run(_ process: Process, commandID: UUID) -> CommandResult {
        do {
            try process.run()
            process.waitUntilExit()
            let completedAt = Date()
            let status = process.terminationStatus
            if status == 0 {
                return .success(commandID: commandID, at: completedAt)
            }
            return .failure(commandID: commandID, at: completedAt, error: .nonZeroExit(status))
        } catch {
            return .failure(
                commandID: commandID, at: Date(),
                error: .processLaunchFailed(String(describing: error)))
        }
    }
}
