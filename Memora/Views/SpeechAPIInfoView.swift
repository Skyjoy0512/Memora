import SwiftUI

struct SpeechAPIInfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SpeechAnalyzer API チェック")
                .font(MemoraTypography.title2)
                .fontWeight(.semibold)

            Divider()

            if #available(iOS 26.0, *) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: SpeechAnalyzerFeatureFlag.isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(SpeechAnalyzerFeatureFlag.isEnabled ? MemoraColor.accentGreen : MemoraColor.accentRed)
                        Text("iOS 26 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()

                    if SpeechAnalyzerFeatureFlag.isEnabled {
                        Text("SpeechAnalyzer（ベータ）が有効です")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.accentGreen)
                            .padding(.horizontal)
                    } else {
                        Text("SpeechAnalyzer は現在無効です（設定から有効化可能）")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                Text("iOS 26 SpeechAnalyzer API はベータ版です。設定から有効にできます。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(MemoraColor.accentBlue)
                        Text("iOS 10-25 対応デバイス")
                            .font(MemoraTypography.body)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                Text("現在は SFSpeechRecognizer を使用し、SpeechAnalyzer 非対応端末をカバーします。")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }

            Divider()

            Text("iOS バージョン: \(UIDevice.current.systemVersion)")
                .font(MemoraTypography.caption1)
                .foregroundStyle(.secondary)

            Button("OK", role: .cancel) { }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .padding()
    }
}

#Preview {
    SpeechAPIInfoView()
}
