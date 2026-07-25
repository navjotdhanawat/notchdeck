import Foundation

public struct BridgeConfig: Codable, Equatable, Sendable {
    public let port: UInt16
    public let token: String
    public init(port: UInt16, token: String) { self.port = port; self.token = token }
}

public enum BridgeConfigWriter {
    public static func write(_ config: BridgeConfig, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func read(from url: URL) throws -> BridgeConfig {
        try JSONDecoder().decode(BridgeConfig.self, from: Data(contentsOf: url))
    }
}
