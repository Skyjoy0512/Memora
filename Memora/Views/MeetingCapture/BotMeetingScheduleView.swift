import SwiftUI

struct BotMeetingScheduleView: View {
    @Bindable var viewModel: BotMeetingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                platformSection
                detailsSection
                scheduleSection
                actionSection
            }
            .scrollContentBackground(.hidden)
            .background(MemoraColor.surfacePrimary)
            .navigationTitle("Bot 会議予約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage { Text(msg) }
            }
        }
    }

    // MARK: - Platform

    private var platformSection: some View {
        Section {
            Picker("プラットフォーム", selection: $viewModel.selectedPlatform) {
                ForEach(MeetingPlatform.allCases.filter { $0 != .other }, id: \.self) { platform in
                    HStack(spacing: 6) {
                        Image(systemName: platform.iconName)
                        Text(platform.displayName)
                    }
                    .tag(platform)
                }
            }
        } header: {
            Text("プラットフォーム")
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section {
            TextField("会議名", text: $viewModel.meetingTitle)
                .submitLabel(.done)

            TextField("会議URL", text: $viewModel.meetingURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .submitLabel(.done)

            HStack {
                Text("所要時間")
                Spacer()
                Picker("", selection: $viewModel.durationMinutes) {
                    Text("30分").tag(30)
                    Text("60分").tag(60)
                    Text("90分").tag(90)
                    Text("120分").tag(120)
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text("会議の詳細")
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            DatePicker(
                "開始日時",
                selection: $viewModel.scheduledDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .environment(\.locale, Locale(identifier: "ja_JP"))
        } header: {
            Text("日時")
        }
    }

    // MARK: - Action

    private var actionSection: some View {
        Section {
            Button {
                Task { await viewModel.scheduleMeeting() }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Botを予約する", systemImage: "bot.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!viewModel.canSchedule)
            .listRowBackground(Color.clear)

            if !viewModel.canSchedule {
                VStack(alignment: .leading, spacing: 4) {
                    if !viewModel.botService.isConfigured {
                        Label("サーバー設定が必要です。設定タブでBot接続を設定してください", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if viewModel.meetingTitle.isEmpty {
                        Text("会議名を入力してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if viewModel.meetingURL.isEmpty {
                        Text("会議URLを入力してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            }
        }
    }
}

#Preview {
    BotMeetingScheduleView(viewModel: BotMeetingViewModel())
}
