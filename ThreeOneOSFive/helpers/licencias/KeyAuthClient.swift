import Foundation

struct KeyAuthError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct LicenseStatus: Equatable {
    let valid: Bool
    let message: String
    let expiresAt: String?
}

actor KeyAuthClient {
    static let shared = KeyAuthClient()

    private var sessionID: String?

    // MARK: Sesión

    func initialize() async throws {
        let json = try await post(to: LicenseConfig.apiBase, params: [
            "type": "init",
            "ver": LicenseConfig.version,
            "name": LicenseConfig.appName,
            "ownerid": LicenseConfig.ownerID
        ])
        guard let sid = json["sessionid"] as? String, !sid.isEmpty else {
            throw KeyAuthError(message: "El servidor no devolvió una sesión.")
        }
        sessionID = sid
        log("license: sesión iniciada")
    }

    // MARK: Licencia

    func validate(key: String) async throws -> LicenseStatus {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeyAuthError(message: "Introduce una licencia.") }

        if sessionID == nil { try await initialize() }
        guard let sid = sessionID else { throw KeyAuthError(message: "Sesión no inicializada.") }

        let json = try await post(to: LicenseConfig.apiBase, params: [
            "type": "license",
            "key": trimmed,
            "hwid": HardwareID.current(),
            "sessionid": sid
        ])

        let expires = (json["expires_at"] as? String) ?? (json["expiry"] as? String)
        let message = (json["message"] as? String) ?? "Licencia válida."
        return LicenseStatus(valid: true, message: message, expiresAt: expires)
    }

    func recheck() async throws {
        if sessionID == nil { try await initialize() }
        guard let sid = sessionID else { throw KeyAuthError(message: "Sesión no inicializada.") }
        _ = try await post(to: LicenseConfig.apiBase, params: [
            "type": "check",
            "sessionid": sid
        ])
    }

    func logout() async {
        guard let sid = sessionID else { return }
        _ = try? await post(to: LicenseConfig.apiBase, params: [
            "type": "logout",
            "sessionid": sid
        ])
        sessionID = nil
    }

    // MARK: Generador de pruebas (seller API)

    func createLicense(expiryDays: Int = 1, level: Int = 1, mask: String = "ARGENT-****") async throws -> String {
        let json = try await post(to: LicenseConfig.sellerBase, params: [
            "sellerkey": LicenseConfig.sellerKey,
            "type": "add",
            "expiry": String(expiryDays),
            "mask": mask,
            "level": String(level),
            "amount": "1"
        ])

        if let key = json["key"] as? String { return key }
        if let keys = json["keys"] as? [String], let first = keys.first { return first }
        throw KeyAuthError(message: json["message"] as? String ?? "El servidor no devolvió ninguna clave.")
    }

    // MARK: Transporte

    private func post(to base: URL, params: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("3105", forHTTPHeaderField: "User-Agent")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .keyAuthFormAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw KeyAuthError(message: "Sin conexión con el servidor de licencias.")
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw KeyAuthError(message: "El servidor respondió \(http.statusCode).")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyAuthError(message: "Respuesta no válida del servidor.")
        }
        guard json["success"] as? Bool == true else {
            throw KeyAuthError(message: json["message"] as? String ?? "Operación rechazada.")
        }
        return json
    }
}

private extension CharacterSet {
    static let keyAuthFormAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~!*'()")
        return set
    }()
}