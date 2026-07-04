import SwiftUI

struct MeetingCaptureSetupView: View {
    @Bindable var viewModel: MeetingCaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var botScheduleSucceeded = false

    var body: some View {
        NavigationStack {
            if viewModel.captureStatus == .capturing || viewModel.captureStatus == .settingUp {
                MeetingCaptureProgressView(viewModel: viewModel, onStop: { viewModel.stopCapture() })
                    .navigationTitle("キャプチャ中")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { viewModel.stopCapture() }
                        }
                    }
            } else {
                setupForm
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil || viewModel.botViewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil; viewModel.botViewModel.errorMessage = nil } }
        )) {
            Button("OK") {
                viewModel.errorMessage = nil
                viewModel.botViewModel.errorMessage = nil
            }
        } message: {
            if let msg = viewModel.errorMessage ?? viewModel.botViewModel.errorMessage { Text(msg) }
        }
    }

    // MARK: - Setup Form

    private var setupForm: some View {
        Form {
            modeSection
            platformSection
            calendarSection
            detailsSection

            if viewModel.captureMode == .bot {
                scheduleSection
            }

            actionSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("会議キャプチャ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        Section {
            Picker("キャプチャ方法", selection: $viewModel.captureMode) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.captureMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("キャプチャ方法")
        }
    }

    // MARK: - Platform

    private var platformSection: some View {
        Section {
            if viewModel.captureMode == .bot {
                Picker("プラットフォーム", selection: $viewModel.selectedPlatform) {
                    ForEach(MeetingPlatform.allCases.filter { $0 != .other }, id: \.self) { platform in
                        HStack(spacing: 6) {
                            Image(systemName: platform.iconName)
                            Text(platform.displayName)
                        }
                        .tag(platform)
                    }
                }
            } else {
                ForEach(MeetingPlatform.allCases, id: \.self) { platform in
                    Button {
                        viewModel.selectedPlatform = platform
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: platform.iconName)
                                .font(.title3)
                                .foregroundStyle(viewModel.selectedPlatform == platform ? .blue : .secondary)
                                .frame(width: 28)

                            Text(platform.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if viewModel.selectedPlatform == platform {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } header: {
            Text("プラットフォーム")
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        Section {
            calendarButton

            if !viewModel.upcomingMeetings.isEmpty {
                ForEach(viewModel.upcomingMeetings) { meeting in
                    Button {
                        viewModel.applyCalendarMeeting(meeting)
                    } label: {
                        HStack(spacing: MemoraSpacing.sm) {
                            Image(systemName: meeting.platform.iconName)
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                                Text(meeting.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MemoraColor.textPrimary)
                                    .lineLimit(1)

                                Text(meeting.formattedStartTime)
                                    .font(.caption)
                                    .foregroundStyle(MemoraColor.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.turn.down.left")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                switch viewModel.calendarAccessStatus {
                case .denied:
                    calendarStatusMessage(
                        icon: "lock.shield",
                        text: "カレンダーへのアクセスが許可されていません。設定アプリから許可してください。",
                        color: .orange
                    )
                case .noMeetings:
                    calendarStatusMessage(
                        icon: "calendar.badge.exclamationmark",
                        text: "今後7日間に会議URLを含む予定は見つかりませんでした。",
                        color: .secondary
                    )
                case .notRequested, .authorized:
                    EmptyView()
                }
            }
        } header: {
            Text("カレンダー連携")
        }
    }

    private var calendarButton: some View {
        Button {
            Task { await viewModel.loadUpcomingMeetings() }
        } label: {
            Label("カレンダーから選択", systemImage: "calendar")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }

    private func calendarStatusMessage(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: MemoraSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.vertical, MemoraSpacing.xxs)
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section {
            TextField("会議名", text: $viewModel.meetingTitle)
                .submitLabel(.done)

            TextField(viewModel.captureMode == .bot ? "会議URL" : "会議URL（任意）", text: $viewModel.meetingURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .submitLabel(.done)
        } header: {
            Text("会議の詳細")
        }
    }

    // MARK: - Schedule (Bot only)

    private var scheduleSection: some View {
        Section {
            HStack {
                Text("所要時間")
                Spacer()
                Picker("", selection: $viewModel.botViewModel.durationMinutes) {
                    Text("30分").tag(30)
                    Text("60分").tag(60)
                    Text("90分").tag(90)
                    Text("120分").tag(120)
                }
                .pickerStyle(.segmented)
            }

            DatePicker(
                "開始日時",
                selection: $viewModel.botViewModel.scheduledDate,
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
            if viewModel.captureMode == .bot {
                botActionButton
            } else {
                localActionContent
            }

            statusMessage
        }
    }

    private var localActionContent: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.startMonitoring()
            } label: {
                HStack {
                    Spacer()
                    Label("キャプチャ準備開始", systemImage: "record.circle")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!viewModel.canStartCapture)

            if viewModel.captureStatus == .settingUp || viewModel.captureStatus == .capturing {
                SystemBroadcastPicker()
                    .frame(height: 44)

                Text("上のボタンをタップしてシステム録音を開始します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if !viewModel.canStartCapture {
                EmptyView()
            } else {
                Text("「キャプチャ準備開始」をタップ後、システム録音を開始してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .listRowBackground(Color.clear)
    }

    private var botActionButton: some View {
        Button {
            Task {
                await viewModel.scheduleBot()
                if viewModel.botViewModel.errorMessage == nil {
                    botScheduleSucceeded = true
                    dismiss()
                }
            }
        } label: {
            HStack {
                Spacer()
                if viewModel.botViewModel.isLoading {
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
        .disabled(!viewModel.canScheduleBot)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if viewModel.captureMode == .bot {
            if !viewModel.canScheduleBot {
                VStack(alignment: .leading, spacing: 4) {
                    if !viewModel.botViewModel.botService.isConfigured {
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
        } else {
            if !viewModel.canStartCapture && !viewModel.meetingTitle.isEmpty {
                Text("キャプチャサービスが利用できません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

#Preview {
    MeetingCaptureSetupView(viewModel: MeetingCaptureViewModel())
}
