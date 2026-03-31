import SwiftUI

struct AuthView: View {
    @AppStorage("hasAuthenticated") private var hasAuthenticated = false
    @AppStorage("hasShownPaywall") private var hasShownPaywall = false

    var body: some View {
        VStack(spacing: MemoraSpacing.xxl) {
            Spacer()

            // アイコン
            ZStack {
                Circle()
                    .fill(MemoraColor.accentBlue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(MemoraColor.accentBlue)
            }

            VStack(spacing: MemoraSpacing.sm) {
                Text("Memoraへようこそ")
                    .font(MemoraTypography.title2)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("サインインして始めましょう")
                    .font(MemoraTypography.body)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Spacer()

            // Sign in with Apple
            Button {
                // TODO: Sign in with Apple 実装 (TASK-008)
                hasAuthenticated = true
                hasShownPaywall = false
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "apple.logo")
                    Text("Appleでサインイン")
                        .font(MemoraTypography.body)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .clipShape(Capsule())
            }

            // Sign in with Google
            Button {
                // TODO: Sign in with Google 実装 (TASK-008)
                hasAuthenticated = true
                hasShownPaywall = false
            } label: {
                HStack(spacing: MemoraSpacing.sm) {
                    Image(systemName: "globe")
                    Text("Googleでサインイン")
                        .font(MemoraTypography.body)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(MemoraColor.divider.opacity(0.1))
                .clipShape(Capsule())
            }

            Spacer()
                .frame(height: MemoraSpacing.xl)
        }
        .padding(.horizontal, MemoraSpacing.xxl)
        .background(MemoraColor.surfacePrimary)
    }
}

#Preview {
    AuthView()
}
