import SwiftUI

// MARK: - Summary Tab

struct SummaryTab: View {
    @Bindable var vm: FileDetailViewModel
    let audioFile: AudioFile
    let showGenerationFlow: Binding<Bool>
    let showShareSheet: Binding<Bool>

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: MemoraSpacing.lg) {
                if vm.isSummarizing {
                    progressCard(
                        title: "要約を生成中",
                        progress: vm.summarizationProgress,
                        message: "要点とアクションアイテムを整理しています。"
                    )
                } else if let result = vm.summaryResult {
                    SummaryContentView(result: result)

                    // Summary タブの context-aware actions
                    HStack(spacing: MemoraSpacing.sm) {
                        Button {
                            showGenerationFlow.wrappedValue = true
                        } label: {
                            Label("再生成", systemImage: "arrow.clockwise")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Menu {
                            Button {
                                showShareSheet.wrappedValue = true
                            } label: {
                                Label("共有", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                                .font(MemoraTypography.caption1)
                        }
                        .buttonStyle(.bordered)
                    }
                } else if audioFile.isSummarized {
                    placeholderCard(
                        icon: "text.quote",
                        title: "要約を読み込めませんでした",
                        description: "保存済みデータの取得後に、このタブへ表示されます。"
                    )
                } else if vm.transcriptResult != nil || audioFile.isTranscribed {
                    placeholderCard(
                        icon: "sparkles.rectangle.stack",
                        title: "要約をまだ作成していません",
                        description: "文字起こしから要約を生成すると、ここに本文と重要ポイントが表示されます。"
                    )
                } else {
                    placeholderCard(
                        icon: "text.quote",
                        title: "先に文字起こしが必要です",
                        description: "要約タブは文字起こし結果をもとに作成されます。まず Transcript タブで文字起こしを実行してください。"
                    )
                }
            }
            .padding(.bottom, 72)

            // 下部全幅「要約を生成」ボタン
            if !vm.isSummarizing && vm.summaryResult == nil && !audioFile.isSummarized && (vm.transcriptResult != nil || audioFile.isTranscribed) {
                Button {
                    showGenerationFlow.wrappedValue = true
                } label: {
                    Text("要約を生成")
                        .font(MemoraTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MemoraSpacing.md)
                        .background { MemoraColor.accentPrimary }
                        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
                }
                .padding(.horizontal, MemoraSpacing.md)
                .padding(.bottom, MemoraSpacing.md)
            }
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
}
