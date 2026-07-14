import SwiftUI

enum V6AuthStage: String {
    case onboarding
    case login
    case paywall
    case done
}

enum V6AuthStorageKey {
    static let stage = "v6AuthStage"
    static let isPro = "v6IsPro"
    static let loginEmail = "v6LoginEmail"
}

struct V6AuthFlowView: View {
    @Binding var authStageRaw: String
    @Binding var isPro: Bool
    @Binding var loginEmail: String
    @Binding var toastMessage: String?

    @State private var onboardingIndex = 0
    @State private var loginStep = V6LoginStep.buttons
    @State private var emailDraft = ""
    @State private var loginCode = ""
    @State private var selectedPlan = V6Plan.annual

    private let slides = [
        V6OnboardingSlide(kind: .record, title: "録音するだけ", description: "会議も雑談も、ボタンひとつで記録できます。"),
        V6OnboardingSlide(kind: .summary, title: "AI が要約・タスク化", description: "決定事項と次のアクションを自動で抽出します。"),
        V6OnboardingSlide(kind: .ask, title: "Ask AI に聞くだけ", description: "「先週決まったことは？」と話しかけるだけで答えます。")
    ]

    private var stage: V6AuthStage {
        V6AuthStage(rawValue: authStageRaw) ?? .onboarding
    }

    var body: some View {
        ZStack {
            V6Color.white.ignoresSafeArea()

            switch stage {
            case .onboarding:
                onboardingView
            case .login:
                loginView
            case .paywall:
                paywallView(closeLabel: "あとで") {
                    authStageRaw = V6AuthStage.done.rawValue
                }
            case .done:
                EmptyView()
            }
        }
        .foregroundStyle(V6Color.ink)
    }

    private var onboardingView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("スキップ") { authStageRaw = V6AuthStage.login.rawValue }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                    .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, 28)

            VStack(spacing: 32) {
                Spacer()
                onboardingIllustration(for: slides[onboardingIndex].kind)

                VStack(spacing: 8) {
                    Text(slides[onboardingIndex].title)
                        .font(V6Font.authTitle)
                        .foregroundStyle(V6Color.ink)

                    Text(slides[onboardingIndex].description)
                        .font(.system(size: 14))
                        .foregroundStyle(V6Color.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: 270)
                }
                Spacer()
            }

            VStack(spacing: 22) {
                HStack(spacing: 6) {
                    ForEach(slides.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == onboardingIndex ? V6Color.ink : V6Color.line)
                            .frame(width: index == onboardingIndex ? 18 : 6, height: 6)
                    }
                }

                V6PrimaryButton(title: onboardingIndex == slides.count - 1 ? "はじめる" : "次へ") {
                    if onboardingIndex == slides.count - 1 {
                        authStageRaw = V6AuthStage.login.rawValue
                    } else {
                        onboardingIndex += 1
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .background(V6Color.white)
    }

    private var loginView: some View {
        Group {
            switch loginStep {
            case .buttons:
                loginButtonsView
            case .email:
                emailView
            case .code:
                codeView
            }
        }
        .background(V6Color.white)
    }

    private var loginButtonsView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Spacer()
                Text("Memora")
                    .font(V6Font.appTitle)
                    .tracking(-0.68)
                    .foregroundStyle(V6Color.ink)
                Text("会話を記録し、AIが要約する")
                    .font(.system(size: 14))
                    .foregroundStyle(V6Color.muted)
                Spacer()
            }

            VStack(spacing: 10) {
                V6AuthProviderButton(title: "Apple でサインイン", style: .apple) {
                    loginEmail = "apple-user@memora.local"
                    authStageRaw = V6AuthStage.paywall.rawValue
                }
                V6AuthProviderButton(title: "Google で続ける", style: .google) {
                    loginEmail = "google-user@memora.local"
                    authStageRaw = V6AuthStage.paywall.rawValue
                }
                V6AuthProviderButton(title: "メールアドレスで続ける", style: .email) {
                    emailDraft = loginEmail
                    loginStep = .email
                }
            }

            Text("続行すると利用規約とプライバシーポリシーに同意したことになります")
                .font(V6Font.caption)
                .foregroundStyle(V6Color.quiet)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
        .padding(.top, 60)
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }

    private var emailView: some View {
        VStack(spacing: 0) {
            HStack {
                V6IconBackButton { loginStep = .buttons }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text("メールアドレスを入力")
                    .font(V6Font.authTitle)
                    .foregroundStyle(V6Color.ink)
                TextField("you@example.com", text: $emailDraft)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
                    .foregroundStyle(V6Color.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(V6Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous)
                            .stroke(V6Color.line, lineWidth: 1)
                    }
                Spacer()
            }
            .padding(.horizontal, 24)

            V6PrimaryButton(title: "確認コードを送信", isEnabled: emailDraft.contains("@")) {
                guard emailDraft.contains("@") else { return }
                loginEmail = emailDraft
                loginCode = ""
                loginStep = .code
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private var codeView: some View {
        VStack(spacing: 0) {
            HStack {
                V6IconBackButton { loginStep = .email }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("確認コードを入力")
                        .font(V6Font.authTitle)
                        .foregroundStyle(V6Color.ink)
                    Text("\(loginEmail) 宛に6桁のコードを送信しました")
                        .font(V6Font.bodySmall)
                        .foregroundStyle(V6Color.muted)
                }

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Text(codeCharacter(at: index))
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(V6Color.ink)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(V6Color.line, lineWidth: 1)
                            }
                    }
                }

                TextField("コードを入力", text: $loginCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(V6Color.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .overlay {
                        RoundedRectangle(cornerRadius: V6Radius.field, style: .continuous)
                            .stroke(V6Color.line, lineWidth: 1)
                    }
                    .onChange(of: loginCode) { _, newValue in
                        loginCode = String(newValue.filter(\.isNumber).prefix(6))
                    }
                Spacer()
            }
            .padding(.horizontal, 24)

            V6PrimaryButton(title: "確認", isEnabled: loginCode.count == 6) {
                guard loginCode.count == 6 else { return }
                authStageRaw = V6AuthStage.paywall.rawValue
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private func paywallView(closeLabel: String, close: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(closeLabel, action: close)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V6Color.quiet)
                    .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Memora Pro")
                            .font(V6Font.proTitle)
                            .tracking(-0.26)
                            .foregroundStyle(V6Color.ink)
                        Text("すべての記録を、どこからでも")
                            .font(.system(size: 13.5))
                            .foregroundStyle(V6Color.muted)
                    }
                    .padding(.bottom, 22)

                    VStack(spacing: 12) {
                        ForEach(proFeatures, id: \.self) { feature in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(V6Color.ink)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 18, height: 18)
                                Text(feature)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(V6Color.ink)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.bottom, 22)

                    HStack(spacing: 10) {
                        planCard(.annual, title: "年額", price: "¥9,800", detail: "月あたり¥817", badge: "2ヶ月分お得")
                        planCard(.monthly, title: "月額", price: "¥980", detail: "いつでも解約可", badge: nil)
                    }
                    .padding(.bottom, 20)

                    V6PrimaryButton(title: "7日間無料で試す") {
                        isPro = true
                        authStageRaw = V6AuthStage.done.rawValue
                        toastMessage = "Pro へようこそ"
                    }
                    .padding(.bottom, 8)

                    Text("いつでもキャンセルできます")
                        .font(.system(size: 11.5))
                        .foregroundStyle(V6Color.quiet)
                        .padding(.bottom, 16)

                    HStack(spacing: 16) {
                        Text("購入を復元")
                        Text("利用規約")
                        Text("プライバシー")
                    }
                    .font(V6Font.caption)
                    .foregroundStyle(V6Color.quiet)
                }
                .padding(.top, 6)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .background(V6Color.white)
    }

    private var proFeatures: [String] {
        [
            "文字起こし 月1200分（無料: 300分）",
            "添付のクラウド保存・全デバイス同期",
            "ライフログ自動セグメント無制限",
            "Ask AI 無制限（無料: 1日10回）"
        ]
    }

    @ViewBuilder
    private func onboardingIllustration(for kind: V6OnboardingKind) -> some View {
        switch kind {
        case .record:
            ZStack {
                Circle()
                    .fill(V6Color.ink)
                    .frame(width: 88, height: 88)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(V6Color.white)
                    .frame(width: 30, height: 30)
            }
        case .summary:
            VStack(alignment: .leading, spacing: 0) {
                Text("決定事項")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                    .padding(.bottom, 8)
                Capsule().fill(V6Color.line).frame(width: 169, height: 8).padding(.bottom, 6)
                Capsule().fill(V6Color.line).frame(width: 122, height: 8).padding(.bottom, 14)
                Text("次のアクション")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                    .padding(.bottom, 8)
                Capsule().fill(V6Color.line).frame(width: 141, height: 8)
            }
            .padding(16)
            .frame(width: 220)
            .background(V6Color.faint, in: RoundedRectangle(cornerRadius: V6Radius.cardAlt, style: .continuous))
        case .ask:
            HStack(spacing: 10) {
                Text("Search or Ask")
                    .font(.system(size: 13))
                    .foregroundStyle(V6Color.muted)
                Spacer()
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 18)
            .frame(width: 220, height: 52)
            .background(V6Color.ink, in: Capsule())
        }
    }

    private func codeCharacter(at index: Int) -> String {
        guard loginCode.indices.contains(loginCode.index(loginCode.startIndex, offsetBy: index, limitedBy: loginCode.endIndex) ?? loginCode.endIndex) else {
            return " "
        }
        let stringIndex = loginCode.index(loginCode.startIndex, offsetBy: index)
        return String(loginCode[stringIndex])
    }

    private func planCard(_ plan: V6Plan, title: String, price: String, detail: String, badge: String?) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(V6Color.ink, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .offset(y: -25)
                        .padding(.bottom, -18)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(V6Color.ink)
                Text(price)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(V6Color.ink)
                Text(detail)
                    .font(V6Font.caption)
                    .foregroundStyle(V6Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .overlay {
                RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous)
                    .stroke(selectedPlan == plan ? V6Color.ink : V6Color.cardBorderInactive, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum V6OnboardingKind {
    case record
    case summary
    case ask
}

private struct V6OnboardingSlide {
    let kind: V6OnboardingKind
    let title: String
    let description: String
}

private enum V6LoginStep {
    case buttons
    case email
    case code
}

private enum V6Plan {
    case annual
    case monthly
}

private struct V6AuthProviderButton: View {
    enum Style {
        case apple
        case google
        case email
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if style == .apple {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 17, weight: .semibold))
                } else if style == .google {
                    V6GoogleLogoMark()
                        .frame(width: 17, height: 17)
                }
                Text(title)
                    .font(V6Font.buttonSmall)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: V6Radius.providerButton, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .google ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch style {
        case .apple:
            V6Color.ink
        case .google:
            V6Color.white
        case .email:
            V6Color.soft
        }
    }

    private var labelColor: Color {
        style == .apple ? .white : V6Color.ink
    }

    private var borderColor: Color {
        style == .google ? V6Color.line : .clear
    }
}

/// Official Google "G" mark, transcribed from the design's 18×18 SVG paths (brand-accurate
/// four-color mark, per Google Sign-In branding guidelines — not a simplified placeholder).
private struct V6GoogleLogoMark: View {
    var body: some View {
        ZStack {
            bluePath.fill(Color(hex: "4285F4"))
            greenPath.fill(Color(hex: "34A853"))
            yellowPath.fill(Color(hex: "FBBC05"))
            redPath.fill(Color(hex: "EA4335"))
        }
        .frame(width: 18, height: 18)
    }

    private var bluePath: Path {
        Path { p in
            p.move(to: CGPoint(x: 17.6, y: 9.2))
            p.addCurve(to: CGPoint(x: 17.4, y: 7.4), control1: CGPoint(x: 17.6, y: 8.6), control2: CGPoint(x: 17.5, y: 8.0))
            p.addLine(to: CGPoint(x: 9, y: 7.4))
            p.addLine(to: CGPoint(x: 9, y: 10.8))
            p.addLine(to: CGPoint(x: 13.8, y: 10.8))
            p.addCurve(to: CGPoint(x: 12.0, y: 13.5), control1: CGPoint(x: 13.6, y: 11.9), control2: CGPoint(x: 13.0, y: 12.9))
            p.addLine(to: CGPoint(x: 12.0, y: 15.8))
            p.addLine(to: CGPoint(x: 14.9, y: 15.8))
            p.addCurve(to: CGPoint(x: 17.6, y: 9.2), control1: CGPoint(x: 16.6, y: 14.2), control2: CGPoint(x: 17.6, y: 11.9))
            p.closeSubpath()
        }
    }

    private var greenPath: Path {
        Path { p in
            p.move(to: CGPoint(x: 9, y: 18))
            p.addCurve(to: CGPoint(x: 15, y: 15.8), control1: CGPoint(x: 11.4, y: 18), control2: CGPoint(x: 13.5, y: 17.2))
            p.addLine(to: CGPoint(x: 12.1, y: 13.5))
            p.addCurve(to: CGPoint(x: 9.0, y: 14.4), control1: CGPoint(x: 11.3, y: 14.0), control2: CGPoint(x: 10.2, y: 14.4))
            p.addCurve(to: CGPoint(x: 3.9, y: 10.6), control1: CGPoint(x: 6.6, y: 14.4), control2: CGPoint(x: 4.6, y: 12.8))
            p.addLine(to: CGPoint(x: 0.9, y: 10.6))
            p.addLine(to: CGPoint(x: 0.9, y: 12.9))
            p.addCurve(to: CGPoint(x: 9, y: 18), control1: CGPoint(x: 2.5, y: 15.9), control2: CGPoint(x: 5.5, y: 18))
            p.closeSubpath()
        }
    }

    private var yellowPath: Path {
        Path { p in
            p.move(to: CGPoint(x: 3.9, y: 10.6))
            p.addCurve(to: CGPoint(x: 3.6, y: 9.0), control1: CGPoint(x: 3.7, y: 10.1), control2: CGPoint(x: 3.6, y: 9.5))
            p.addCurve(to: CGPoint(x: 3.9, y: 7.4), control1: CGPoint(x: 3.6, y: 8.5), control2: CGPoint(x: 3.7, y: 7.9))
            p.addLine(to: CGPoint(x: 3.9, y: 5.1))
            p.addLine(to: CGPoint(x: 0.9, y: 5.1))
            p.addCurve(to: CGPoint(x: 0, y: 9), control1: CGPoint(x: 0.3, y: 6.3), control2: CGPoint(x: 0, y: 7.6))
            p.addCurve(to: CGPoint(x: 0.9, y: 12.9), control1: CGPoint(x: 0, y: 10.4), control2: CGPoint(x: 0.3, y: 11.7))
            p.addLine(to: CGPoint(x: 3.9, y: 10.6))
            p.closeSubpath()
        }
    }

    private var redPath: Path {
        Path { p in
            p.move(to: CGPoint(x: 9, y: 3.6))
            p.addCurve(to: CGPoint(x: 12.4, y: 4.9), control1: CGPoint(x: 10.3, y: 3.6), control2: CGPoint(x: 11.5, y: 4.1))
            p.addLine(to: CGPoint(x: 15.0, y: 2.3))
            p.addCurve(to: CGPoint(x: 9, y: 0), control1: CGPoint(x: 13.5, y: 0.9), control2: CGPoint(x: 11.4, y: 0))
            p.addCurve(to: CGPoint(x: 0.9, y: 5.1), control1: CGPoint(x: 5.5, y: 0), control2: CGPoint(x: 2.5, y: 2.1))
            p.addLine(to: CGPoint(x: 3.9, y: 7.4))
            p.addCurve(to: CGPoint(x: 9, y: 3.6), control1: CGPoint(x: 4.6, y: 5.2), control2: CGPoint(x: 6.6, y: 3.6))
            p.closeSubpath()
        }
    }
}
