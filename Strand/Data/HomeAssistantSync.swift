import Foundation
import Combine

// Home Assistant integration — pushes NOX's own scores (Charge/Effort/Rest, HRV, resting HR, live
// BPM) to a Home Assistant instance as sensor entities via HA's REST API, so they can drive
// automations and dashboards there. One-way (NOX → HA); NOX never reads anything back from HA.
//
// Everything here is optional and off by default. The base URL and long-lived access token are
// entirely user-supplied (typically a local address like http://homeassistant.local:8123), so this
// stays consistent with NOX's "no cloud, nothing uploaded unless you say so" stance — if HA itself
// is local, this never leaves the home network.

// MARK: - Secure token storage (Keychain)

/// Keychain Services wrapper for the Home Assistant long-lived access token. Mirrors `AIKeyStore`'s
/// approach: a generic-password item under a fixed service, never UserDefaults/plist/disk in the
/// clear.
enum HomeAssistantTokenStore {
    private static let service = "com.jmh.nox.homeassistant"
    private static let account = "long-lived-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { clear(); return true }
        guard let data = trimmed.data(using: .utf8) else { return false }

        SecItemDelete(baseQuery as CFDictionary)

        var attrs = baseQuery
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8),
              !str.isEmpty else { return nil }
        return str
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

// MARK: - Settings

/// Home Assistant connection settings, persisted in UserDefaults (URL, toggles) and Keychain
/// (token). Off by default; nothing is sent unless `enabled` is true and a URL + token are set.
@MainActor
final class HomeAssistantSettings: ObservableObject {
    @Published var enabled: Bool             { didSet { d.set(enabled, forKey: K.enabled) } }
    @Published var baseURLString: String     { didSet { d.set(baseURLString, forKey: K.baseURL) } }
    @Published var pushAfterSync: Bool       { didSet { d.set(pushAfterSync, forKey: K.pushAfterSync) } }
    @Published var entityPrefix: String      { didSet { d.set(entityPrefix, forKey: K.entityPrefix) } }

    /// Not @Published-persisted directly (goes to Keychain), but published so the UI can react.
    @Published var token: String {
        didSet { HomeAssistantTokenStore.save(token) }
    }

    /// Last push attempt, kept in-memory only (not persisted) for a simple status line in Settings.
    @Published var lastResult: String?
    @Published var lastResultWasError = false

    private let d = UserDefaults.standard
    private enum K {
        static let enabled       = "homeAssistant.enabled"
        static let baseURL       = "homeAssistant.baseURL"
        static let pushAfterSync = "homeAssistant.pushAfterSync"
        static let entityPrefix  = "homeAssistant.entityPrefix"
    }

    init() {
        enabled       = d.object(forKey: K.enabled) as? Bool ?? false
        baseURLString = d.string(forKey: K.baseURL) ?? ""
        pushAfterSync = d.object(forKey: K.pushAfterSync) as? Bool ?? true
        entityPrefix  = d.string(forKey: K.entityPrefix) ?? "nox"
        token         = HomeAssistantTokenStore.read() ?? ""
    }

    /// True once there's enough configured to actually attempt a push.
    var isConfigured: Bool {
        enabled && !baseURLString.trimmingCharacters(in: .whitespaces).isEmpty && !token.isEmpty
    }

    var normalizedBaseURL: URL? {
        var s = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s)
    }
}

// MARK: - Errors

enum HomeAssistantError: LocalizedError {
    case notConfigured
    case badURL
    case http(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Home Assistant isn't configured yet. Add a URL and a long-lived access token in Settings.")
        case .badURL:
            return String(localized: "That Home Assistant URL doesn't look valid.")
        case .http(let code, let body):
            return String(localized: "Home Assistant replied with an error (\(code)).") + (body.isEmpty ? "" : " \(body)")
        case .network(let err):
            return err.localizedDescription
        }
    }
}

// MARK: - Client

/// Thin REST client for Home Assistant's `/api/states/<entity_id>` endpoint. One responsibility:
/// turn a value into an HA sensor state. No HA-side reads, no polling, no persistent connection.
struct HomeAssistantClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Quick reachability + auth check: GET /api/, which HA answers with
    /// `{"message": "API running."}` when the token is valid. The trailing slash matters: HA's
    /// router treats "/api" and "/api/" as distinct routes and only registers the latter, so
    /// dropping it produces a 404 even with a perfectly valid token.
    func testConnection(baseURL: URL, token: String) async throws -> Bool {
        // Built via string concatenation, not appendingPathComponent, because that API can silently
        // drop the trailing slash — and the slash is what makes this route exist at all on HA.
        guard let url = URL(string: baseURL.absoluteString + "/api/") else {
            throw HomeAssistantError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 10

        let (data, response) = try await sessionData(req)
        guard let http = response as? HTTPURLResponse else { throw HomeAssistantError.badURL }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw HomeAssistantError.http(http.statusCode, body)
        }
        return true
    }

    /// Creates/updates one HA sensor entity's state. `entityId` should already include the
    /// `sensor.` prefix (e.g. "sensor.nox_charge").
    func pushState(
        baseURL: URL,
        token: String,
        entityId: String,
        state: String,
        attributes: [String: Any] = [:]
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 10

        let body: [String: Any] = ["state": state, "attributes": attributes]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await sessionData(req)
        guard let http = response as? HTTPURLResponse else { throw HomeAssistantError.badURL }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw HomeAssistantError.http(http.statusCode, bodyText)
        }
    }

    private func sessionData(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw HomeAssistantError.network(error)
        }
    }
}

// MARK: - Payload

/// One metric ready to push: the entity id suffix (appended to the user's prefix), its current
/// value as a string, and the attributes HA should store alongside it (unit, friendly name, icon).
struct HomeAssistantMetric {
    let key: String              // e.g. "charge" → becomes "sensor.<prefix>_charge"
    let state: String
    let friendlyName: String
    let unit: String
    let icon: String             // an MDI icon name, e.g. "mdi:battery-charging-80"
}

/// Orchestrates one full push: builds entity ids from the user's prefix, then pushes each metric
/// in turn. Individual metric failures don't abort the batch — partial success (e.g. Wi-Fi drops
/// mid-push) still updates whatever HA already received.
struct HomeAssistantSync {
    let settings: HomeAssistantSettings
    let client: HomeAssistantClient

    init(settings: HomeAssistantSettings, client: HomeAssistantClient = HomeAssistantClient()) {
        self.settings = settings
        self.client = client
    }

    @discardableResult
    @MainActor
    func push(_ metrics: [HomeAssistantMetric]) async -> (succeeded: Int, failed: Int) {
        guard settings.isConfigured, let baseURL = settings.normalizedBaseURL else {
            settings.lastResult = HomeAssistantError.notConfigured.errorDescription
            settings.lastResultWasError = true
            return (0, metrics.count)
        }

        let token = settings.token
        let prefixRaw = settings.entityPrefix.trimmingCharacters(in: .whitespaces)
        let prefix = prefixRaw.isEmpty ? "nox" : prefixRaw

        var succeeded = 0
        var failed = 0
        var lastError: String?

        for metric in metrics {
            let entityId = "sensor.\(prefix)_\(metric.key)"
            let attrs: [String: Any] = [
                "unit_of_measurement": metric.unit,
                "friendly_name": metric.friendlyName,
                "icon": metric.icon
            ]
            do {
                try await client.pushState(baseURL: baseURL, token: token, entityId: entityId,
                                            state: metric.state, attributes: attrs)
                succeeded += 1
            } catch {
                failed += 1
                lastError = error.localizedDescription
            }
        }

        if failed == 0 {
            settings.lastResult = String(localized: "Sent \(succeeded) sensor(s) to Home Assistant.")
            settings.lastResultWasError = false
        } else {
            settings.lastResult = lastError ?? String(localized: "Some sensors failed to send.")
            settings.lastResultWasError = true
        }
        return (succeeded, failed)
    }
}
