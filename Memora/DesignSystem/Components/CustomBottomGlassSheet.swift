import SwiftUI

/// Liquid Glass のボトムシート。
///
/// 画面を黒 40% でディムし、下端からスライドインする。
/// 上端両角のみ大きく角丸（36-44pt）、中央にドラッグインジケータを持つ。
///
/// 使用例:
/// ```swift
/// CustomBottomGlassSheet(isPresented: $showSheet) {
///     VStack(alignment: .leading, spacing: 16) {
///         Text("生成方式")
///         // content rows
///     }
///     .padding(.horizontal, 20)
/// } bottomButton: {
///     AnyView(
///         Button("生成") { }
///             .buttonStyle(.borderedProminent)
///     )
/// }
/// ```
///
/// - iOS 26: `glassEffect(.regular.interactive(), in: .rect(cornerRadius:))`
/// - iOS 17-25: 上端のみ角丸の `.ultraThinMaterial` + 白 overlay + 0.5pt 白 stroke + shadow
struct CustomBottomGlassSheet<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content
    let bottomButton: (() -> AnyView)?

    // MARK: - Layout Constants

    var topCornerRadius: CGFloat = 40
    var dragIndicatorWidth: CGFloat = 72
    var dragIndicatorHeight: CGFloat = 8
    var dragIndicatorTopPadding: CGFloat = 12
    var dragIndicatorBottomPadding: CGFloat = 12
    var contentHorizontalPadding: CGFloat = 20
    var bottomButtonPadding: CGFloat = 20

    // MARK: - Gesture State

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let dismissThreshold: CGFloat = 120

    init(
        isPresented: Binding<Bool>,
        topCornerRadius: CGFloat = 40,
        content: @escaping () -> Content,
        bottomButton: (() -> AnyView)? = nil
    ) {
        self._isPresented = isPresented
        self.topCornerRadius = topCornerRadius
        self.content = content
        self.bottomButton = bottomButton
    }

    var body: some View {
        ZStack {
            if isPresented {
                // Dim overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                    .transition(.opacity)

                // Sheet
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        // Drag indicator
                        Capsule()
                            .fill(MemoraColor.dragIndicator)
                            .frame(width: dragIndicatorWidth, height: dragIndicatorHeight)
                            .padding(.top, dragIndicatorTopPadding)
                            .padding(.bottom, dragIndicatorBottomPadding)

                        // Content
                        content()
                            .padding(.horizontal, contentHorizontalPadding)

                        // Bottom button
                        if let bottomButton = bottomButton {
                            bottomButton()
                                .padding(bottomButtonPadding)
                        }

                        // Safe area spacer for bottom edge
                        Spacer()
                            .frame(height: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        sheetBackgroundShape
                            .fill(.clear)
                            .liquidGlassSheet(cornerRadius: topCornerRadius)
                    }
                    .offset(y: isDragging ? max(0, dragOffset) : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                isDragging = false
                                if value.translation.height > dismissThreshold
                                    || value.predictedEndTranslation.height > dismissThreshold * 2 {
                                    dismiss()
                                }
                                dragOffset = 0
                            }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isDragging)
    }

    private var sheetBackgroundShape: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: topCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: topCornerRadius,
            style: .continuous
        )
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}

// MARK: - Sheet-Specific Liquid Glass Modifier

/// ボトムシート専用の Liquid Glass modifier。
/// 上端のみ角丸の `UnevenRoundedRectangle` をシェイプとして使用する。
private struct LiquidGlassSheetModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )

        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: shape
                )
                .overlay {
                    shape
                        .fill(Color.white.opacity(0.72))
                        .blendMode(.overlay)
                }
                .overlay {
                    shape
                        .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                }
                .shadow(color: MemoraColor.shadowMedium, radius: 12, x: 0, y: -4)
        }
    }
}

private extension View {
    func liquidGlassSheet(cornerRadius: CGFloat) -> some View {
        modifier(LiquidGlassSheetModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        MemoraColor.surfaceBackground
            .ignoresSafeArea()

        Button("Show Sheet") {
            // preview toggle not interactive, static sheet shown
        }

        CustomBottomGlassSheet(isPresented: .constant(true)) {
            VStack(alignment: .leading, spacing: 20) {
                Text("生成方式を選択")
                    .font(MemoraTypography.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自動生成").fontWeight(.semibold)
                            Text("内容に応じて最適な形に自動要約")
                                .font(.caption)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }
                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("カスタム生成").fontWeight(.semibold)
                            Text("テンプレートを選択して要約")
                                .font(.caption)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(MemoraColor.textSecondary)
                    }
                }
            }
        } bottomButton: {
            AnyView(
                Button {

                } label: {
                    Text("生成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(MemoraColor.interactivePrimary)
                        )
                }
                .padding(.horizontal, 20)
            )
        }
    }
}
#endif
