import Foundation

/// Parses a semantic version out of a CLI's `--version` output. Robust to a leading program
/// name (e.g. "codex-cli 0.20.3") or a trailing suffix (e.g. "2.1.217 (Claude Code)") by
/// scanning for the first `major.minor.patch` triple anywhere in the string.
public enum CLIVersion {
    public static func parse(_ output: String) -> (Int, Int, Int)? {
        let scanned = output as NSString
        let re = try? NSRegularExpression(pattern: #"(\d+)\.(\d+)\.(\d+)"#)
        guard let m = re?.firstMatch(in: output, range: NSRange(location: 0, length: scanned.length)),
              m.numberOfRanges == 4,
              let major = Int(scanned.substring(with: m.range(at: 1))),
              let minor = Int(scanned.substring(with: m.range(at: 2))),
              let patch = Int(scanned.substring(with: m.range(at: 3))) else { return nil }
        return (major, minor, patch)
    }

    public static func meetsMinimum(_ output: String, _ min: (Int, Int, Int)) -> Bool {
        guard let v = parse(output) else { return false }
        if v.0 != min.0 { return v.0 > min.0 }
        if v.1 != min.1 { return v.1 > min.1 }
        return v.2 >= min.2
    }
}
