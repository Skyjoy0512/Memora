import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Google Meet Integration Section

struct GoogleMeetSection: View {
    @Bindable var state: SettingsState
    @Environment(\.modelContext) private var modelContext
    @Query private var googleSettingsList: [GoogleMeetSettings]

    private var googleSettings: GoogleMeetSettings? {
        googleSettingsList.first
    }

    var body: some View {
        Section {
            Toggle("Google Meet 連携を有効化", isOn: Binding(
                get: { googleSettings?.isEnabled ?? false },
                set: { newValue in
                    if let settings = googleSettings {
                        settings.isEnabled = newValue
                        settings.updatedAt = Date()
                    } else if newValue {
                        let newSettings = GoogleMeetSettings()
                        newSettings.isEnabled = true
                        newSettings.clientID = state.googleClientID
                        newSettings.redirectURIScheme = state.googleRedirectURI
                        modelContext.insert(newSettings)
                    }
                    try? modelContext.save()
                }
            ))

            if googleSettings?.isEnabled == true {
                TextField("Client ID", text: Binding(
                    get: { state.googleClientID },
                    set: { newValue in
                        state.googleClientID = newValue
                        if let settings = googleSettings {
                            settings.clientID = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .font(.system(.body, design: .monospaced))

                TextField("Redirect URI Scheme", text: Binding(
                    get: { state.googleRedirectURI },
                    set: { newValue in
                        state.googleRedirectURI = newValue
                        if let settings = googleSettings {
                            settings.redirectURIScheme = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .font(.system(.body, design: .monospaced))

                if googleSettings?.isTokenValid == true {
                    HStack(spacing: MemoraSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MemoraColor.accentGreen)
                        Text("認証済み")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                    }

                    if let expiresAt = googleSettings?.tokenExpiresAt {
                        Text("トークン有効期限: \(formatDate(expiresAt))")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                    }

                    Button {
                        state.showGoogleMeetImport = true
                    } label: {
                        Label("Meet からインポート", systemImage: "video.badge.plus")
                            .font(MemoraTypography.subheadline)
                    }

                    Button(role: .destructive) {
                        disconnectGoogle()
                    } label: {
                        Text("連携を解除")
                    }
                } else if !state.googleClientID.isEmpty && !state.googleRedirectURI.isEmpty {
                    Button {
                        Task { await authorizeGoogle() }
                    } label: {
                        HStack {
                            Text("Google で認証")
                            if state.isGoogleAuthorizing {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(state.isGoogleAuthorizing)

                    if let result = state.googleAuthResult {
                        Text(result)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(result.contains("成功") ? MemoraColor.accentGreen : MemoraColor.accentRed)
                    }
                } else {
                    Text("Client ID と Redirect URI Scheme を設定してください")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
            }
        } header: {
            GlassSectionHeader(title: "Google Meet 連携", icon: "video.fill")
        } footer: {
            Text("Google Meet の会議録画・文字起こしをインポートします。Google Cloud Console で OAuth 2.0 Client ID を作成し、Redirect URI Scheme（カスタム URL スキーム）を設定してください。")
        }
        .sheet(isPresented: $state.showGoogleMeetImport) {
            GoogleMeetImportView()
        }
    }

    // MARK: - Actions

    private func authorizeGoogle() async {
        state.isGoogleAuthorizing = true
        state.googleAuthResult = nil

        do {
            let authService = GoogleAuthService()
            let contextProvider = AuthPresentationContextProvider()
            let response = try await authService.authorize(
                clientID: state.googleClientID,
                redirectURIScheme: state.googleRedirectURI,
                contextProvider: contextProvider
            )

            let settings = googleSettings ?? {
                let s = GoogleMeetSettings()
                s.isEnabled = true
                modelContext.insert(s)
                return s
            }()

            settings.clientID = state.googleClientID
            settings.redirectURIScheme = state.googleRedirectURI
            settings.accessToken = response.accessToken
            if let refresh = response.refreshToken {
                settings.refreshToken = refresh
            }
            settings.tokenExpiresAt = response.calculatedExpiresAt
            settings.updatedAt = Date()

            try modelContext.save()
            state.googleAuthResult = "認証に成功しました"
        } catch {
            state.googleAuthResult = "認証に失敗しました。設定を確認して再度お試しください。"
            print("Google認証エラー: \(error.localizedDescription)")
        }

        state.isGoogleAuthorizing = false
    }

    private func disconnectGoogle() {
        if let settings = googleSettings {
            if !settings.accessToken.isEmpty {
                Task {
                    let authService = GoogleAuthService()
                    try? await authService.revokeToken(settings.accessToken)
                }
            }
            settings.accessToken = ""
            settings.refreshToken = ""
            settings.tokenExpiresAt = nil
            settings.updatedAt = Date()
            try? modelContext.save()
        }
        state.googleAuthResult = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
