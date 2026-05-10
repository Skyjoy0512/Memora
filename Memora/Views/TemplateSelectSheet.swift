import SwiftUI
import SwiftData

// MARK: - Template Selection Sheet

/// テンプレート選択ボトムシート — 横スクロールカード + AIモデル選択行
struct TemplateSelectSheet: View {
    @Binding var isPresented: Bool
    @Binding var showModelSheet: Bool
    @Binding var selectedTemplate: GenerationTemplate
    @Binding var selectedModel: AIModelType
    let onStartGeneration: (GenerationConfig) -> Void

    @Query(sort: \CustomSummaryTemplate.createdAt, order: .forward) private var customTemplates: [CustomSummaryTemplate]

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
                .padding(.bottom, 20)

            // Title
            Text("テンプレートを選択")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MemoraColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            // Horizontal scrollable template cards
            templateCardScrollView
                .padding(.bottom, 24)

            // Divider
            Divider()
                .padding(.horizontal, 28)

            // AI model selector row
            aiModelRow
                .padding(.horizontal, 28)
                .padding(.vertical, 16)

            // Divider
            Divider()
                .padding(.horizontal, 28)

            // Generate button
            generateButton
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .glassSheetBackground()
    }

    // MARK: - Template Card ScrollView

    private var templateCardScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Leading spacer for initial padding
                Color.clear.frame(width: 12)

                ForEach(GenerationTemplate.allCases, id: \.self) { template in
                    templateCard(template)
                }

                ForEach(customTemplates) { custom in
                    customTemplateCardView(custom)
                }

                // Trailing spacer for peek
                Color.clear.frame(width: 12)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Built-in Template Card

    private func templateCard(_ template: GenerationTemplate) -> some View {
        let isSelected = selectedTemplate == template
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTemplate = template
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Card icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MemoraColor.surfaceSecondary)
                        .frame(width: 52, height: 52)

                    Image(systemName: template.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(template.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 280, height: 260)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? MemoraColor.accentBlue : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: .black.opacity(isSelected ? 0.08 : 0.04),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Template Card

    private func customTemplateCardView(_ template: CustomSummaryTemplate) -> some View {
        Button {
            // Custom template selection
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MemoraColor.surfaceSecondary)
                        .frame(width: 52, height: 52)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(MemoraColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MemoraColor.textPrimary)

                    Text(template.prompt)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 280, height: 260)
            .background(MemoraColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Model Selector Row

    private var aiModelRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showModelSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)

                Text("AIモデル")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MemoraColor.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Text(selectedModel.displayName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MemoraColor.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MemoraColor.textTertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            var config = GenerationConfig()
            config.template = selectedTemplate
            onStartGeneration(config)
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented = false
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
    }
}

#Preview {
    ZStack {
        Color(hex: "ECECEC").ignoresSafeArea()
        TemplateSelectSheet(
            isPresented: .constant(true),
            showModelSheet: .constant(false),
            selectedTemplate: .constant(.summary),
            selectedModel: .constant(.chatGPT5),
            onStartGeneration: { _ in }
        )
    }
}
