import Foundation

enum LicenseConfig {
    /// API de cliente estándar de KeyAuth.
    static let apiBase = URL(string: "https://keyauth.win/api/1.3/")!

    /// API de administración (solo para generar licencias de prueba).
    static let sellerBase = URL(string: "https://keyauth.win/api/seller/")!

    /// OwnerID de la cuenta dueña de la aplicación.
    static let ownerID = "554yMP2JCV"

    /// Nombre EXACTO de la app en el panel. El espacio va como %20.
    static let appName = "Galaxy X"

    /// Debe coincidir con App Version del panel (1.0).
    static let version = "1.0"

    /// Secret de la app. Solo para el generador de pruebas.
    static let sellerKey = "ab2eb9dcef5a269cf4a4537f3ba43744"
}