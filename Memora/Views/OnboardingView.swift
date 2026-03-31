import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
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
                    .foregroundStyle(MemoraColor.textSecondary)
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

            // Page indicator
            HStack(spacing: MemoraSpacing.xs) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? MemoraColor.accentPrimary : MemoraColor.divider)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.vertical, MemoraSpacing.md)

            // Bottom button
            Button {
                if currentPage < totalPages - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(currentPage < totalPages - 1 ? "次へ" : "始める")
                    .font(MemoraTypography.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: MemoraHeight.button)
                    .background(MemoraColor.accentPrimary)
                    .clipShape(Capsule())
            }
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

            // Icon
            ZStack {
                Circle()
                    .fill(MemoraColor.accentBlue.opacity(MemoraOpacity.medium))
                    .frame(width: MemoraFrame.hero, height: MemoraFrame.hero)

                Image(systemName: pageInfo(page).icon)
                    .font(.system(size: 60))
                    .foregroundStyle(MemoraColor.accentBlue)
            }

            // Text
            VStack(spacing: MemoraSpacing.sm) {
                Text(pageInfo(page).title)
                    .font(MemoraTypography.title1)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(pageInfo(page).description)
                    .font(MemoraTypography.body)
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
