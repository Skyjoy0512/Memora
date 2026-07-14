import SwiftUI

struct V6AccountPlanSection: View {
    @AppStorage(V6AuthStorageKey.stage) private var authStageRaw = V6AuthStage.done.rawValue
    @AppStorage(V6AuthStorageKey.isPro) private var isPro = false
    @AppStorage(V6AuthStorageKey.loginEmail) private var loginEmail = ""
    @AppStorage("v6DeviceConnected") private var v6DeviceConnected = false

    var body: some View {
        Section("アカウント") {
            HStack(spacing: MemoraSpacing.sm) {
                Label("プラン", systemImage: "sparkles")
                Spacer()
                Text(isPro ? "Memora Pro" : "Free")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isPro ? MemoraColor.accentGreen : MemoraColor.textPrimary, in: Capsule())
            }

            if !loginEmail.isEmpty {
                HStack {
                    Label("ログイン", systemImage: "person.crop.circle")
                    Spacer()
                    Text(loginEmail)
                        .foregroundStyle(MemoraColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Button {
                authStageRaw = V6AuthStage.paywall.rawValue
            } label: {
                Label(isPro ? "Pro プランを確認" : "Memora Pro を見る", systemImage: "creditcard")
            }

            Button {
                v6DeviceConnected = false
                authStageRaw = V6AuthStage.onboarding.rawValue
            } label: {
                Label("オンボーディングを再表示", systemImage: "rectangle.stack")
            }

            Button(role: .destructive) {
                isPro = false
                loginEmail = ""
                v6DeviceConnected = false
                authStageRaw = V6AuthStage.login.rawValue
            } label: {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
}
