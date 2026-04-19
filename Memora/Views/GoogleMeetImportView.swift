import SwiftUI
import SwiftData

struct GoogleMeetImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var googleSettingsList: [GoogleMeetSettings]

    @State private var conferences: [GoogleMeetService.ConferenceRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var importingConferenceName: String?
    @State private var importResult: String?

    private var settings: GoogleMeetSettings? {
        googleSettingsList.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && conferences.isEmpty {
                    VStack(spacing: MemoraSpacing.md) {
                        ProgressView()
                            .tint(MemoraColor.textSecondary)
                        Text("会議一覧を取得中...")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: MemoraSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(MemoraColor.accentRed)
                        Text(errorMessage)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentRed)
                            .multilineTextAlignment(.center)
                        Button("再試行") {
                            Task { await loadConferences() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conferences.isEmpty {
                    VStack(spacing: MemoraSpacing.md) {
                        Image(systemName: "video.badge-checkmark")
                            .font(.title)
                            .foregroundStyle(MemoraColor.textSecondary)
                        Text("Google Meet の会議録画が見つかりません")
                            .font(MemoraTypography.subheadline)
                            .foregroundStyle(MemoraColor.textSecondary)
                        Text("Google Workspace で会議録画が有効になっている必要があります")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(conferences) { record in
                            conferenceRow(record)
                        }
                    }
                }
            }
            .navigationTitle("Google Meet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .overlay {
                if let importResult {
                    importResultBanner
                }
            }
        }
        .task {
            await loadConferences()
        }
    }

    // MARK: - Conference Row

    @ViewBuilder
    private func conferenceRow(_ record: GoogleMeetService.ConferenceRecord) -> some View {
        Button {
            importConference(record)
        } label: {
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: "video.fill")
                    .foregroundStyle(MemoraColor.accentBlue)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.space?.meetingCode ?? record.name)
                        .font(MemoraTypography.subheadline)
                        .foregroundStyle(.primary)

                    if let startDate = record.startDate {
                        Text(formatDate(startDate))
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                    }
                }

                Spacer()

                if importingConferenceName == record.name {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(MemoraColor.textSecondary)
                }
            }
            .padding(.vertical, MemoraSpacing.xxxs)
        }
        .disabled(importingConferenceName != nil)
    }

    // MARK: - Import Result Banner

    private var importResultBanner: some View {
        VStack {
            Spacer()
            HStack(spacing: MemoraSpacing.sm) {
                Image(systemName: importResult?.contains("成功") == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(importResult?.contains("成功") == true ? MemoraColor.accentGreen : MemoraColor.accentRed)
                Text(importResult ?? "")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(radius: 4)
            .padding(.bottom, MemoraSpacing.xl)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: MemoraAnimation.standardDuration), value: importResult)
    }

    // MARK: - Functions

    private func loadConferences() async {
        guard let settings, settings.isTokenValid else {
            errorMessage = "Google Meet 連携が設定されていません。設定画面から連携を有効にしてください。"
            return
        }

        isLoading = true
        errorMessage = nil

        var token = KeychainService.load(key: .googleMeetAccessToken)

        // トークンリフレッシュが必要な場合
        if settings.shouldRefreshToken {
            do {
                let authService = GoogleAuthService()
                let response = try await authService.refreshToken(
                    clientID: settings.clientID,
                    refreshToken: KeychainService.load(key: .googleMeetRefreshToken)
                )
                token = response.accessToken
                KeychainService.save(key: .googleMeetAccessToken, value: response.accessToken)
                if let newRefresh = response.refreshToken {
                    KeychainService.save(key: .googleMeetRefreshToken, value: newRefresh)
                }
                KeychainService.saveDate(key: .googleMeetTokenExpiresAt, value: response.calculatedExpiresAt)
                settings.updatedAt = Date()
                try? modelContext.save()
            } catch {
                errorMessage = "トークンの更新に失敗しました: \(error.localizedDescription)"
                isLoading = false
                return
            }
        }

        do {
            let service = GoogleMeetService()
            conferences = try await service.fetchConferenceRecords(token: token)
        } catch {
            errorMessage = "会議一覧の取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func importConference(_ record: GoogleMeetService.ConferenceRecord) {
        guard let settings else { return }

        importingConferenceName = record.name
        importResult = nil

        Task {
            do {
                let service = GoogleMeetService()
                let audioFile = try await service.importConferenceRecord(
                    record: record,
                    token: KeychainService.load(key: .googleMeetAccessToken),
                    modelContext: modelContext
                )

                if let audioFile {
                    importResult = "インポート成功: \(audioFile.title)"
                } else {
                    importResult = "インポート対象が見つかりませんでした（録画・文字起こしなし）"
                }
            } catch {
                importResult = "エラー: \(error.localizedDescription)"
            }

            importingConferenceName = nil

            // 3秒後にバナーを消す
            try? await Task.sleep(for: .seconds(3))
            importResult = nil
        }
    }

    private static let importDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.importDateFormatter.string(from: date)
    }
}
