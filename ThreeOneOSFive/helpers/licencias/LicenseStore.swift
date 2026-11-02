import Foundation

@MainActor
final class LicenseStore: ObservableObject {
    enum State: Equatable { case locked, working, unlocked, failure(String) }

    @Published private(set) var state: State = .locked

    private let client = KeyAuthClient.shared
    private let keyAccount = "license.key"
    private let lastCheckAccount = "license.lastCheck"
    private let grace: TimeInterval = 60 * 60 * 24

    var isUnlocked: Bool { state == .unlocked }
    var storedKey: String? { Keychain.get(keyAccount) }

    func restore() async {
        guard let key = storedKey, !key.isEmpty else {
            state = .locked
            return
        }
        state = .working
        do {
            _ = try await client.validate(key: key)
            markChecked()
            state = .unlocked
        } catch {
            if withinGrace() {
                log("license: servidor no disponible, aplicando gracia")
                state = .unlocked
            } else {
                state = .failure((error as? KeyAuthError)?.message ?? "No se pudo validar la licencia.")
            }
        }
    }

    func activate(_ key: String) async {
        state = .working
        do {
            _ = try await client.validate(key: key)
            Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: keyAccount)
            markChecked()
            state = .unlocked
        } catch {
            state = .failure((error as? KeyAuthError)?.message ?? "Licencia rechazada.")
        }
    }

    func generateTrial() async -> String? {
        do {
            return try await client.createLicense()
        } catch {
            state = .failure((error as? KeyAuthError)?.message ?? "No se pudo generar la licencia.")
            return nil
        }
    }

    func revalidateIfNeeded() async {
        guard isUnlocked, let key = storedKey, !key.isEmpty else { return }
        do {
            _ = try await client.validate(key: key)
            markChecked()
        } catch {
            if !withinGrace() { state = .failure("Licencia caducada o sin conexión.") }
        }
    }

    func signOut() async {
        await client.logout()
        Keychain.delete(keyAccount)
        state = .locked
    }

    private func markChecked() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckAccount)
    }

    private func withinGrace() -> Bool {
        let last = UserDefaults.standard.double(forKey: lastCheckAccount)
        guard last > 0 else { return false }
        return Date().timeIntervalSince1970 - last < grace
    }
}