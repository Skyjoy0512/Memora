import SwiftUI

struct Gemma4BenchmarkView: View {
    @State private var runner = Gemma4BenchmarkRunner()

    var body: some View {
        List {
            Section("ベンチマーク") {
                Button {
                    Task { await runner.runAll() }
                } label: {
                    HStack(spacing: MemoraSpacing.sm) {
                        if runner.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                                .foregroundStyle(MemoraColor.accentBlue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(runner.isRunning ? "実行中..." : "ベンチマーク実行")
                                .font(MemoraTypography.subheadline)
                                .foregroundStyle(.primary)

                            Text("3 種類のテストでレイテンシを計測")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(runner.isRunning)
            }

            if !runner.results.isEmpty {
                Section("結果") {
                    ForEach(runner.results) { result in
                        VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? MemoraColor.accentGreen : MemoraColor.accentRed)

                                Text(result.testName)
                                    .font(MemoraTypography.subheadline)

                                Spacer()

                                if result.success {
                                    Text(String(format: "%.0fms", result.latencyMs))
                                        .font(MemoraTypography.caption1)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(MemoraColor.accentBlue)
                                }
                            }

                            if result.success {
                                HStack(spacing: MemoraSpacing.sm) {
                                    Label("\(result.tokenCount) tokens", systemImage: "text.word.spacing")
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.textSecondary)

                                    Label(String(format: "%.1f tok/s", result.tokensPerSecond), systemImage: "speedometer")
                                        .font(MemoraTypography.caption2)
                                        .foregroundStyle(MemoraColor.textSecondary)
                                }
                            } else if let error = result.errorMessage {
                                Text(error)
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(MemoraColor.accentRed)
                            }
                        }
                        .padding(.vertical, MemoraSpacing.xxxs)
                    }
                }

                Section("サマリー") {
                    let successResults = runner.results.filter(\.success)
                    if !successResults.isEmpty {
                        let avgLatency = successResults.map(\.latencyMs).reduce(0, +) / Double(successResults.count)
                        let avgTps = successResults.map(\.tokensPerSecond).reduce(0, +) / Double(successResults.count)

                        LabeledContent("平均レイテンシ", value: String(format: "%.0fms", avgLatency))
                        LabeledContent("平均スループット", value: String(format: "%.1f tok/s", avgTps))
                        LabeledContent("成功率", value: "\(successResults.count)/\(runner.results.count)")
                    } else {
                        Text("すべてのテストが失敗しました")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentRed)
                    }
                }
            }
        }
        .navigationTitle("Gemma 4 Benchmark")
        .navigationBarTitleDisplayMode(.inline)
    }
}
