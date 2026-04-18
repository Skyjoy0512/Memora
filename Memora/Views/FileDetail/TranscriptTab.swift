import SwiftUI

// MARK: - Transcript Tab

struct TranscriptTab: View {
    @Bindable var vm: FileDetailViewModel
    let audioFile: AudioFile
    let showShareSheet: Binding<Bool>

    var body: some View {
        VStack(spacing: MemoraSpacing.lg) {
            if vm.isTranscribing {
                progressCard(
                    title: "文字起こしを実行中",
                    progress: vm.transcriptionProgress,
                    message: "音声を解析して、話者ごとのテキストを整えています。"
                )
            } else if let result = vm.transcriptResult {
                if vm.isEditingTranscript {
                    ScrollView {
                        TextField("文字起こし内容", text: $vm.transcriptDraft, axis: .vertical)
                            .font(MemoraTypography.body)
                            .lineLimit(8...)
                            .padding(MemoraSpacing.sm)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            vm.saveTranscriptEdit()
                        } label: {
                            Label("保存", systemImage: "checkmark")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.cancelEditTranscript()
                        } label: {
                            Label("キャンセル", systemImage: "xmark")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                } else {
                    TranscriptContentView(
                        result: result,
                        currentPlaybackTime: vm.playbackPosition
                    ) { segment in
                        vm.seekToTime(segment.startTime)
                    }

                    // Transcript タブの context-aware actions
                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            vm.startTranscription()
                        } label: {
                            Label("再文字起こし", systemImage: "arrow.clockwise")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isTranscribing)

                        Button {
                            vm.beginEditTranscript()
                        } label: {
                            Label("編集", systemImage: "pencil")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        if result.segments.count > 1 {
                            Button {
                                vm.registerPrimarySpeakerSample()
                            } label: {
                                Label("話者登録", systemImage: "person.crop.circle.badge.plus")
                                    .font(MemoraTypography.caption1)
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                    }
                }

                if let reason = vm.fallbackReason, !reason.isEmpty {
                    detailCard {
                        HStack(spacing: MemoraSpacing.sm) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(MemoraColor.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("バックエンド: \(vm.activeBackend ?? "不明")")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.primary)
                                Text(reason)
                                    .font(MemoraTypography.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if audioFile.isTranscribed {
                placeholderCard(
                    icon: "text.alignleft",
                    title: "文字起こしを読み込めませんでした",
                    description: "保存済みデータの取得後に、このタブへ全文を表示します。"
                )
            } else {
                placeholderCard(
                    icon: "waveform.badge.magnifyingglass",
                    title: "文字起こしはまだありません",
                    description: "録音を文字起こしすると、全文と話者セグメントをこのタブで確認できます。",
                    buttonTitle: "文字起こしを開始",
                    buttonAction: { vm.startTranscription() }
                )
            }

            if let referenceTranscript = audioFile.referenceTranscript, !referenceTranscript.isEmpty {
                detailCard {
                    VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                        Label("参照文字起こし（Plaud）", systemImage: "doc.text")
                            .font(MemoraTypography.headline)
                            .foregroundStyle(MemoraColor.accentBlue)

                        Text(referenceTranscript)
                            .font(MemoraTypography.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(6)

                        Text("Plaud 側で生成された文字起こしです。Memora の文字起こしとは独立しています。")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 話者登録（Transcript タブ内）
            speakerRegistrationCard
        }
    }

    // MARK: - Helper Views

    private func progressCard(title: String, progress: Double, message: String) -> some View {
        detailCard {
            VStack(alignment: .leading, spacing: MemoraSpacing.md) {
                Text(title)
                    .font(MemoraTypography.headline)

                ProgressView(value: progress)
                    .tint(MemoraColor.textSecondary)

                Text("\(Int(progress * 100))%  \(message)")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func placeholderCard(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) -> some View {
        detailCard {
            EmptyStateView(
                icon: icon,
                title: title,
                description: description,
                buttonTitle: buttonTitle,
                buttonAction: buttonAction
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(MemoraSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoraColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.lg))
    }

    @ViewBuilder
    private var speakerRegistrationCard: some View {
        if vm.audioURL != nil {
            detailCard {
                Button(action: { vm.registerPrimarySpeakerSample() }) {
                    VStack(spacing: 6) {
                        Label("この録音を自分の声サンプルに登録", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                        Text("1人だけが話している録音を使うと精度が安定します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
    }
}
