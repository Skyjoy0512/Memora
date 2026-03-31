import SwiftUI

struct PaywallView: View {
    @AppStorage("hasShownPaywall") private var hasShownPaywall = false

    var body: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            Image(systemName: "sparkles.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(MemoraColor.accentBlue)

            VStack(spacing: MemoraSpacing.sm) {
                Text("Memora Pro")
                    .font(MemoraTypography.title2)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("すべての機能を使い放題")
                    .font(MemoraTypography.body)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            // プラン一覧
            VStack(spacing: MemoraSpacing.md) {
                planRow(icon: "waveform", title: "無制限録音")
                planRow(icon: "text.alignleft", title: "AI文字起こし")
                planRow(icon: "text.quote", title: "自動要約")
                planRow(icon: "checklist", title: "ToDo抽出")
            }
            .padding()
            .background(MemoraColor.divider.opacity(0.05))
            .cornerRadius(MemoraRadius.md)

            Spacer()

            // 購入ボタン
            Button {
                // TODO: StoreKit 2 実装 (TASK-009)
                hasShownPaywall = true
            } label: {
                Text("無料トライアルを始める")
                    .font(MemoraTypography.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(MemoraColor.accentPrimary)
                    .clipShape(Capsule())
            }

            Button("後で") {
                hasShownPaywall = true
            }
            .foregroundStyle(MemoraColor.textSecondary)

            Spacer()
                .frame(height: MemoraSpacing.xl)
        }
        .padding(.horizontal, MemoraSpacing.xxl)
        .background(MemoraColor.surfacePrimary)
    }

    private func planRow(icon: String, title: String) -> some View {
        HStack(spacing: MemoraSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(MemoraColor.accentBlue)
                .frame(width: 24)

            Text(title)
                .font(MemoraTypography.body)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(MemoraTypography.caption1)
                .foregroundStyle(MemoraColor.accentGreen)
        }
    }
}

#Preview {
    PaywallView()
}
