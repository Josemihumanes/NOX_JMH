import SwiftUI
import StrandDesign

struct HomeAssistantSettingsView: View {
    @StateObject private var settings = HomeAssistantSettings()
    @State private var isTesting = false
    @State private var isSendingTest = false

    var body: some View {
        ScreenScaffold(title: "Home Assistant",
                       subtitle: "Send your NOX scores to a Home Assistant instance as sensors, so they can drive automations and dashboards there. One-way: NOX never reads anything back from Home Assistant. If your Home Assistant runs on your own network, this never leaves it.") {
            VStack(alignment: .leading, spacing: NoopMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: NoopMetrics.cardInnerSpacing) {
                    SectionHeader("Connection", overline: "Setup")
                    connectionCard
                }
                VStack(alignment: .leading, spacing: NoopMetrics.cardInnerSpacing) {
                    SectionHeader("Test", overline: "Verify")
                    testCard
                }
            }
        }
    }

    private var connectionCard: some View {
        StrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $settings.enabled) {
                    Text("Enabled")
                        .font(StrandFont.body)
                }
                .tint(StrandPalette.chargeColor)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL").font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                    TextField("http://homeassistant.local:8123", text: $settings.baseURLString)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Long-Lived Access Token").font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                    SecureField("Paste your token", text: $settings.token)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Text("Create one from your Home Assistant profile page → Security → Long-Lived Access Tokens.")
                        .font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Entity prefix").font(StrandFont.footnote).foregroundStyle(StrandPalette.textSecondary)
                    TextField("nox", text: $settings.entityPrefix)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Text("Sensors will be created as sensor.\(settings.entityPrefix.isEmpty ? "nox" : settings.entityPrefix)_charge, _effort, _rest, and so on.")
                        .font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                }

                Divider()

                Toggle(isOn: $settings.pushAfterSync) {
                    Text("Push automatically after each sync")
                        .font(StrandFont.body)
                }
                .tint(StrandPalette.chargeColor)
            }
        }
    }

    private var testCard: some View {
        StrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTesting { ProgressView().controlSize(.small) }
                        Text("Test connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canAttempt || isTesting)

                Button {
                    Task { await sendTestValues() }
                } label: {
                    HStack {
                        if isSendingTest { ProgressView().controlSize(.small) }
                        Text("Send sample sensors now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canAttempt || isSendingTest)

                if let result = settings.lastResult {
                    Label {
                        Text(result).font(StrandFont.footnote)
                    } icon: {
                        Image(systemName: settings.lastResultWasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    }
                    .foregroundStyle(settings.lastResultWasError ? .orange : StrandPalette.chargeColor)
                }
            }
        }
    }

    private var canAttempt: Bool {
        settings.normalizedBaseURL != nil && !settings.token.isEmpty
    }

    private func testConnection() async {
        guard let url = settings.normalizedBaseURL else {
            settings.lastResult = HomeAssistantError.badURL.errorDescription
            settings.lastResultWasError = true
            return
        }
        isTesting = true
        defer { isTesting = false }
        do {
            _ = try await HomeAssistantClient().testConnection(baseURL: url, token: settings.token)
            settings.lastResult = String(localized: "Connected. Home Assistant accepted the token.")
            settings.lastResultWasError = false
        } catch {
            settings.lastResult = error.localizedDescription
            settings.lastResultWasError = true
        }
    }

    private func sendTestValues() async {
        isSendingTest = true
        defer { isSendingTest = false }
        let sync = HomeAssistantSync(settings: settings)
        _ = await sync.push([
            HomeAssistantMetric(key: "charge", state: "56", friendlyName: "NOX Charge", unit: "pts", icon: "mdi:battery-charging-80"),
            HomeAssistantMetric(key: "effort", state: "18", friendlyName: "NOX Effort", unit: "pts", icon: "mdi:lightning-bolt"),
            HomeAssistantMetric(key: "rest", state: "57", friendlyName: "NOX Rest", unit: "pts", icon: "mdi:sleep")
        ])
    }
}
