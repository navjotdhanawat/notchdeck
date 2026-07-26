import Foundation

public final class LicenseManager: @unchecked Sendable {
    public static let shared = LicenseManager()

    private enum Key {
        static let licenseKey   = "notchdeck.license.key"
        static let machineId    = "notchdeck.license.machineId"
        static let validatedAt  = "notchdeck.license.validatedAt"
        static let tier         = "notchdeck.license.tier"
    }

    public enum Tier: String { case free, pro }

    public enum LicenseError: LocalizedError {
        case invalidKey, alreadyActivated, networkUnavailable, serverError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidKey:         return "License key not found."
            case .alreadyActivated:   return "This key is already activated on another Mac."
            case .networkUnavailable: return "Could not reach the license server. Check your connection."
            case .serverError(let m): return m
            }
        }
    }

    // v1: everything is free. Set to .pro after successful key activation.
    @Published public private(set) var currentTier: Tier = .free

    private let apiBase = "https://notchdeck.com/api/license"
    private let revalidateInterval: TimeInterval = 7 * 24 * 3600

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Key.tier),
           let t = Tier(rawValue: saved) {
            currentTier = t
        }
    }

    // MARK: - Public API

    /// Call on app launch to restore and re-validate a stored key.
    public func activateIfStored() async {
        guard let key = storedKey else { return }
        await revalidateIfNeeded(key: key)
    }

    public func activate(_ key: String) async throws {
        let trimmed = key.uppercased().trimmingCharacters(in: .whitespaces)
        let response = try await call(endpoint: "activate", body: ["key": trimmed, "machine_id": machineId])

        guard let valid = response["valid"] as? Bool, valid else {
            switch response["reason"] as? String ?? "" {
            case "invalid_key":       throw LicenseError.invalidKey
            case "already_activated": throw LicenseError.alreadyActivated
            case let r:               throw LicenseError.serverError(r)
            }
        }

        UserDefaults.standard.set(trimmed, forKey: Key.licenseKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.validatedAt)
        setTier(.pro)
    }

    public func deactivate() {
        UserDefaults.standard.removeObject(forKey: Key.licenseKey)
        UserDefaults.standard.removeObject(forKey: Key.validatedAt)
        setTier(.free)
    }

    // MARK: - Feature gates
    // v1: all features unlocked for everyone.
    // When paid tier ships, gate these on currentTier == .pro.
    public var canUseAllAgents:  Bool { true }
    public var canUseActInPlace: Bool { true }
    public var canAccessHistory: Bool { true }
    public var canUseAllThemes:  Bool { true }

    // MARK: - Private

    private var storedKey: String? {
        UserDefaults.standard.string(forKey: Key.licenseKey)
    }

    private var machineId: String {
        if let id = UserDefaults.standard.string(forKey: Key.machineId) { return id }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: Key.machineId)
        return new
    }

    private func revalidateIfNeeded(key: String) async {
        let last = UserDefaults.standard.double(forKey: Key.validatedAt)
        guard Date().timeIntervalSince1970 - last > revalidateInterval else { return }

        do {
            let response = try await call(endpoint: "validate", body: ["key": key, "machine_id": machineId])
            let valid = response["valid"] as? Bool ?? false
            setTier(valid ? .pro : .free)
            if valid {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.validatedAt)
            }
        } catch {
            // Offline — keep existing tier, retry next launch
        }
    }

    private func setTier(_ tier: Tier) {
        currentTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: Key.tier)
    }

    private func call(endpoint: String, body: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: "\(apiBase)/\(endpoint)") else {
            throw LicenseError.networkUnavailable
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LicenseError.networkUnavailable }
        guard http.statusCode == 200 else { throw LicenseError.serverError("HTTP \(http.statusCode)") }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
