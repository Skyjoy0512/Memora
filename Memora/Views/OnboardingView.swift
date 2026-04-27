import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                if currentPage < totalPages - 1 {
                    Button("スキップ") {
                        completeOnboarding()
                    }
                    .font(MemoraTypography.chatToken)
                    .foregroundStyle(MemoraColor.textTertiary)
                    .padding(MemoraSpacing.md)
                }
            }

            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<totalPages, id: \.self) { page in
                    pageContent(page)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator (NothingPageIndicator)
            NothingPageIndicator(
                totalPages: totalPages,
                currentPage: $currentPage
            )
            .padding(.vertical, MemoraSpacing.md)

            // Bottom CTA button (PillButton .nothing style)
            PillButton(
                title: currentPage < totalPages - 1 ? "次へ" : "始める",
                action: {
                    if currentPage < totalPages - 1 {
                        MemoraAnimation.animate(reduceMotion) { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                },
                style: .primary
            )
            .padding(.horizontal, MemoraSpacing.xl)
            .padding(.bottom, MemoraSpacing.xl)
        }
        .background(MemoraColor.surfacePrimary)
    }

    // MARK: - Page Content

    @ViewBuilder
    private func pageContent(_ page: Int) -> some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            // Icon: clean circle with divider border
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 160, height: 160)
                    .overlay {
                        Circle()
                            .stroke(MemoraColor.divider, lineWidth: 1.5)
                            .frame(width: 160, height: 160)
                    }

                Image(systemName: pageInfo(page).icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(MemoraColor.textTertiary)
            }

            // Text
            VStack(spacing: MemoraSpacing.sm) {
                Text(pageInfo(page).title)
                    .font(MemoraTypography.phiTitle)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(pageInfo(page).description)
                    .font(MemoraTypography.chatBody)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MemoraSpacing.xxl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func pageInfo(_ page: Int) -> (icon: String, title: String, description: String) {
        switch page {
        case 0:
            return ("waveform.circle", "Memoraについて", "会議録音をAIで自動議事録化")
        case 1:
            return ("text.alignleft", "AI文字起こし", "高精度な音声認識で会話を文字に変換")
        case 2:
            return ("text.quote", "智能要約", "会議内容を自動要約し、決定事項を抽出")
        case 3:
            return ("checklist", "行動管理", "ToDoを自動生成し、プロジェクトごとに管理")
        default:
            return ("star", "", "")
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
