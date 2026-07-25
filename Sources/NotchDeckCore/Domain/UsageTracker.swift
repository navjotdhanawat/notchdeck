// Sources/ClaudeNotchCore/Domain/UsageTracker.swift
import Foundation

/// Tracks per-transcript read offsets and accumulates token usage across incremental scans,
/// producing an up-to-date `SessionUsage` (with estimated cost) after each event.
/// Keyed by transcript path; serialized by the actor.
public actor UsageTracker {
    private struct Entry { var offset: Int; var totals: TokenUsage; var model: String? }
    private var entries: [String: Entry] = [:]
    private let reader: TranscriptReading

    public init(reader: TranscriptReading) {
        self.reader = reader
    }

    /// Incrementally read `transcriptPath` using the agent's parser + estimator, and return current usage.
    public func update(transcriptPath: String, parser: TranscriptParsing, estimator: CostEstimator) -> SessionUsage {
        let previous = entries[transcriptPath] ?? Entry(offset: 0, totals: TokenUsage(), model: nil)
        let scan = reader.scan(path: transcriptPath, from: previous.offset, parser: parser)
        let entry: Entry
        if scan.newOffset < previous.offset {
            entry = Entry(offset: scan.newOffset, totals: scan.usageDelta, model: scan.model)
        } else {
            entry = Entry(offset: scan.newOffset,
                          totals: previous.totals + scan.usageDelta,
                          model: scan.model ?? previous.model)
        }
        entries[transcriptPath] = entry
        let cost = estimator.cost(model: entry.model, tokens: entry.totals)
        return SessionUsage(model: entry.model, tokens: entry.totals, costUSD: cost)
    }

    /// Drop tracked offsets/totals for a transcript when its session ends (spec §14 cleanup).
    public func forget(transcriptPath: String) {
        entries[transcriptPath] = nil
    }
}
