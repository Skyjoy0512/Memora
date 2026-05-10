import SwiftUI

/// 画面下部に浮かぶ Liquid Glass タブバー。
///
/// 4 タブ（Home, ToDo, Setting, AskAI）を想定。
/// 選択中タブには `#D9D9D9` の角丸背景が表示される。
///
/// 使用例:
/// ```swift
/// FloatingGlassTabBar(
///     selectedTab: $selectedTab,
///     tabs: [
///         ("house", "Home"),
///         ("checkmark.circle", "ToDo"),
///         ("gearshape", "Setting"),
///         ("sparkles", "AskAI")
///     ]
/// )
/// ```
///
/// - 全体高さ ~96pt、左右余白 ~40pt、下部余白 ~34pt（呼び出し側で `.padding(.bottom, 34)` を付与）
/// - iOS 26: `glassEffect(.regular.interactive(), in: .rect(cornerRadius:))`
/// - iOS 17-25: `.ultraThinMaterial` fallback
/// - 親ビューが `GlassEffectContainer` でこのバーと FAB を囲うことで、iOS 26 でのガラス融合が得られる
struct FloatingGlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]

    // MARK: - Layout Constants

    private let barHeight: CGFloat = 96
    private let cornerRadius: CGFloat = 48
    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 16
    private let tabIconSize: CGFloat = 24
    private let tabLabelSize: CGFloat = 10
    private let tabSpacing: CGFloat = 4
    private let selectedPillVRatio: CGFloat = 0.72

    /// 選択タブ背景の角丸
    private var selectedPillCornerRadius: CGFloat {
        MemoraRadius.md  // 13pt
    }

    init(
        selectedTab: Binding<Int>,
        tabs: [(icon: String, label: String)]
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                tabButton(index: index, icon: tab.icon, label: tab.label)
            }
        }
        .frame(height: barHeight)
        .padding(.horizontal, horizontalPadding)
        .background {
            if #available(iOS 26.0, *) {
                // Note: 親ビューが GlassEffectContainer でラップすることで
                // 近接するガラス要素（FAB 等）との自然な融合が得られる。
                // GlassEffectContainer がない場合は単独の glassEffect として機能。
                EmptyView()
            } else {
                EmptyView()
            }
        }
        .liquidGlass(cornerRadius: cornerRadius)
    }

    // MARK: - Tab Button

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: tabSpacing) {
                Image(systemName: icon)
                    .font(.system(size: tabIconSize, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? MemoraColor.textPrimary
                            : MemoraColor.textSecondary
                    )
                    .frame(height: tabIconSize)

                Text(label)
                    .font(.system(size: tabLabelSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? MemoraColor.textPrimary
                            : MemoraColor.textSecondary
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight - verticalPadding * 2)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedPillCornerRadius, style: .continuous)
                        .fill(MemoraColor.tabSelectedBg)
                        .padding(.horizontal, 2)
                        .padding(.vertical, (barHeight - verticalPadding * 2) * (1 - selectedPillVRatio) / 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        MemoraColor.surfaceBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            FloatingGlassTabBar(
                selectedTab: .constant(0),
                tabs: [
                    ("house", "Home"),
                    ("checkmark.circle", "ToDo"),
                    ("gearshape", "Setting"),
                    ("sparkles", "AskAI")
                ]
            )
        }
    }
}
#endif
