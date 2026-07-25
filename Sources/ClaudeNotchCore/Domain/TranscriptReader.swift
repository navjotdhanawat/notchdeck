// Sources/ClaudeNotchCore/Domain/TranscriptReader.swift
import Foundation

/// Reads newly-appended transcript bytes from a byte offset and parses them.
public protocol TranscriptReading: Sendable {
    func scan(path: String, from offset: Int, parser: TranscriptParsing) -> TranscriptScan
}

/// File-backed reader. Reads from `offset` to EOF; only consumes up to the last complete line
/// (a trailing partial line is left for the next scan). Resets to 0 if the file shrank
/// (rotation/truncation). Any I/O failure yields an empty delta and never throws to the caller.
public struct FileTranscriptReader: TranscriptReading {
    public init() {}

    public func scan(path: String, from offset: Int, parser: TranscriptParsing) -> TranscriptScan {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return TranscriptScan(newOffset: offset)
        }
        defer { try? handle.close() }
        do {
            let size = Int(try handle.seekToEnd())
            var start = offset
            if start > size { start = 0 }                 // rotated/truncated → re-scan from top
            guard size > start else { return TranscriptScan(newOffset: start) }
            try handle.seek(toOffset: UInt64(start))
            let data = try handle.read(upToCount: size - start) ?? Data()
            guard let lastNL = data.lastIndex(of: 0x0A) else {
                return TranscriptScan(newOffset: start)   // no complete line yet
            }
            let complete = data[...lastNL]
            let consumed = start + complete.count
            let (model, usage) = parser.parse(String(decoding: complete, as: UTF8.self))
            return TranscriptScan(newOffset: consumed, model: model, usageDelta: usage)
        } catch {
            return TranscriptScan(newOffset: offset)
        }
    }
}
