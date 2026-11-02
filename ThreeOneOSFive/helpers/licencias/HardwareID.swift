import Foundation
import CryptoKit
import UIKit

enum HardwareID {
    private static let saltAccount = "3105.hwid.salt"

    /// Identificador estable por instalación (IDFV + sal persistida, SHA-256).
    static func current() -> String {
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "no-idfv"
        let digest = SHA256.hash(data: Data("\(idfv)|\(storedSalt())".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Cambia la sal: el dispositivo pasa a contar como nuevo.
    static func reset() {
        Keychain.set(UUID().uuidString, for: saltAccount)
    }

    private static func storedSalt() -> String {
        if let existing = Keychain.get(saltAccount) { return existing }
        let fresh = UUID().uuidString
        Keychain.set(fresh, for: saltAccount)
        return fresh
    }
}