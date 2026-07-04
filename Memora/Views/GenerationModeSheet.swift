import SwiftUI

// MARK: - Generation Mode Sheet

/// 生成方式選択ボトムシート — 自動生成 / カスタム生成の2択
struct GenerationModeSheet: View {
    @Binding var isPresented: Bool
    @Binding var showTemplateSheet: Bool
    let onStartGeneration: (GenerationConfig) -> Void

    @State private var selectedMode: GenerationMode = .auto

    enum GenerationMode {
        case auto
        case custom
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background overlay — 40% black, tappable to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }

            // Sheet content
            sheetContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color(hex: "A7A7A7"))
                .frame(width: 72, height: 8)
                .padding(.top, 16)
                .padding(.bottom, 24)

            // Mode selection rows
            VStack(spacing: 0) {
                modeRow(
                    icon: "sparkles",
                    title: "自動生成",
                    subtitle: "内容に応じて最適な形に自動要約",
                    mode: .auto
                )

                Divider()
                    .padding(.leading, 60)

                modeRow(
                    icon: "square.grid.3x3",
                    title: "カスタム生成",
                    subtitle: "テンプレートを選択して要約",
                    mode: .custom,
                    showChevron: true
                )
            }
            .padding(.horizontal, 28)

            Spacer()

            // Generate button
            generateButton
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .glassSheetBackground()
    }

    // MARK: - Mode Row

    private func modeRow(
        icon: String,
        title: String,
        subtitle: String,
        mode: GenerationMode,
        showChevron: Bool = false
    ) -> some View {
        Button {
            selectedMode = mode
            if mode == .custom {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                    showTemplateSheet = true
                }
            }
        } label: {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(MemoraColor.surfaceSecondary)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MemoraColor.textTertiary)
                }
            }
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            if selectedMode == .auto {
                let config = GenerationConfig()
                onStartGeneration(config)
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPresented = false
                }
            }
        } label: {
            Text("生成")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(MemoraColor.interactivePrimary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .opacity(selectedMode == .custom ? 0 : 1)
        .disabled(selectedMode == .custom)
    }
}

// MARK: - Glass Sheet Background Modifier

private struct GlassSheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 36))
                )
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.white, lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 36)
                                .fill(Color.white.opacity(0.72))
                                .blendMode(.overlay)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.white, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }
}

extension View {
    func glassSheetBackground() -> some View {
        modifier(GlassSheetBackgroundModifier())
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        GenerationModeSheet(
            isPresented: .constant(true),
            showTemplateSheet: .constant(false),
            onStartGeneration: { _ in }
        )
    }
}
