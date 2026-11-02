import SwiftUI
import UIKit

struct LicenseGateView: View {
    @EnvironmentObject private var store: LicenseStore
    @State private var key = ""
    @State private var showHWID = false
    @State private var generating = false

    private var working: Bool { store.state == .working }
    private var accent: Color { Color(red: 0.90, green: 0.46, blue: 0.23) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(accent)
                        .padding(.top, 64)

                    Text("Licencia requerida")
                        .font(.title2.bold())

                    Text("Introduce tu clave para desbloquear 3105.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("XXXX-XXXX-XXXX", text: $key)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(white: 0.11), in: .rect(cornerRadius: 12))
                        .disabled(working)

                    Button {
                        Task { await store.activate(key) }
                    } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(.white) }
                            Text(working ? "Comprobando…" : "Activar").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accent, in: .rect(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .disabled(working || key.trimmingCharacters(in: .whitespaces).isEmpty)

                    if case .failure(let message) = store.state {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Divider().padding(.vertical, 4)

                    Button {
                        generating = true
                        Task {
                            if let generated = await store.generateTrial() {
                                key = generated
                                UIPasteboard.general.string = generated
                            }
                            generating = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if generating { ProgressView().controlSize(.small) }
                            Text("Generar licencia de 1 día").font(.footnote)
                        }
                    }
                    .disabled(generating)

                    Button {
                        showHWID.toggle()
                    } label: {
                        Text(showHWID ? "Ocultar ID del dispositivo" : "Ver ID del dispositivo")
                            .font(.footnote)
                    }

                    if showHWID {
                        VStack(spacing: 10) {
                            Text(HardwareID.current())
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .multilineTextAlignment(.center)
                            HStack(spacing: 18) {
                                Button("Copiar") { UIPasteboard.general.string = HardwareID.current() }
                                Button("Restablecer") { HardwareID.reset() }
                                    .foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                        }
                        .padding(12)
                        .background(Color(white: 0.09), in: .rect(cornerRadius: 10))
                    }
                }
                .padding(24)
            }
        }
    }
}