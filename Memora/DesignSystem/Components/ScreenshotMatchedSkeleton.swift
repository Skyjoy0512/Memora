import SwiftUI

/// スクリーンショット一致のためのスケルトンプレースホルダー。
///
/// 色は `#D9D9D9`（`MemoraColor.skeletonBase`）と
/// `#F3F3F3`（`MemoraColor.skeletonLight`）を使用。
/// 静的グレー表示が基本。必要に応じて shimmer も選択可能。
///
/// 使用例:
/// ```swift
/// // カードスケルトン（アイコン + テキスト行）
/// ScreenshotMatchedSkeleton.card()
///
/// // 本文スケルトン（複数の横長バー）
/// ScreenshotMatchedSkeleton.bodyLines(count: 4)
///
/// // 個別のバー
/// ScreenshotMatchedSkeleton.Bar(widthRatio: 0.7, height: 16, cornerRadius: 8)
///
/// // 大きめの画像プレースホルダー
/// ScreenshotMatchedSkeleton.Bar(height: 200, cornerRadius: 20)
/// ```
struct ScreenshotMatchedSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 生成するスケルトンバーの定義
    let bars: [BarSpec]
    var spacing: CGFloat
    var useShimmer: Bool

    @State private var shimmerOffset: CGFloat = -300

    struct BarSpec: Equatable {
        var widthRatio: CGFloat
        var height: CGFloat
        var cornerRadius: CGFloat
        var color: Color

        init(
            widthRatio: CGFloat = 1.0,
            height: CGFloat = 16,
            cornerRadius: CGFloat = MemoraRadius.sm,
            color: Color = MemoraColor.skeletonBase
        ) {
            self.widthRatio = widthRatio
            self.height = height
            self.cornerRadius = cornerRadius
            self.color = color
        }
    }

    init(
        bars: [BarSpec],
        spacing: CGFloat = MemoraSpacing.sm,
        useShimmer: Bool = false
    ) {
        self.bars = bars
        self.spacing = spacing
        self.useShimmer = useShimmer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, spec in
                Bar(
                    widthRatio: spec.widthRatio,
                    height: spec.height,
                    cornerRadius: spec.cornerRadius,
                    color: spec.color,
                    shimmerOffset: useShimmer ? shimmerOffset : nil
                )
            }
        }
        .clipped()
        .onAppear {
            guard useShimmer, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
    }
}

// MARK: - Skeleton Bar

extension ScreenshotMatchedSkeleton {
    /// 単一のスケルトンバー。横長の角丸矩形。
    struct Bar: View {
        var widthRatio: CGFloat
        var height: CGFloat
        var cornerRadius: CGFloat
        var color: Color
        var shimmerOffset: CGFloat?

        init(
            widthRatio: CGFloat = 1.0,
            height: CGFloat = 16,
            cornerRadius: CGFloat = MemoraRadius.sm,
            color: Color = MemoraColor.skeletonBase,
            shimmerOffset: CGFloat? = nil
        ) {
            self.widthRatio = widthRatio
            self.height = height
            self.cornerRadius = cornerRadius
            self.color = color
            self.shimmerOffset = shimmerOffset
        }

        var body: some View {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(
                        width: geometry.size.width * widthRatio,
                        height: height
                    )
                    .overlay {
                        if let offset = shimmerOffset {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0),
                                            .init(
                                                color: Color.white.opacity(0.4),
                                                location: 0.5
                                            ),
                                            .init(color: .clear, location: 1),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: offset)
                        }
                    }
                    .clipped()
            }
            .frame(height: height)
        }
    }
}

// MARK: - Factory Methods

extension ScreenshotMatchedSkeleton {
    /// ファイルカードのスケルトン（アイコン円 + タイトル行 + サブ行）。
    static func card(useShimmer: Bool = false) -> ScreenshotMatchedSkeleton {
        ScreenshotMatchedSkeleton(
            bars: [
                // Icon circle + title row (approximated as bars)
                BarSpec(widthRatio: 0.15, height: 44, cornerRadius: 22,
                        color: MemoraColor.skeletonLight),
                BarSpec(widthRatio: 0.6, height: 16, cornerRadius: MemoraRadius.sm),
                BarSpec(widthRatio: 0.4, height: 14, cornerRadius: MemoraRadius.sm,
                        color: MemoraColor.skeletonLight),
            ],
            spacing: MemoraSpacing.sm,
            useShimmer: useShimmer
        )
    }

    /// 本文の複数行スケルトン。
    static func bodyLines(
        count: Int = 4,
        useShimmer: Bool = false
    ) -> ScreenshotMatchedSkeleton {
        let widths: [CGFloat] = [0.95, 0.88, 0.72, 0.91, 0.65, 0.83]
        let bars: [BarSpec] = (0..<count).map { i in
            BarSpec(
                widthRatio: widths[i % widths.count],
                height: 14,
                cornerRadius: MemoraRadius.sm
            )
        }
        return ScreenshotMatchedSkeleton(
            bars: bars,
            spacing: MemoraSpacing.sm,
            useShimmer: useShimmer
        )
    }

    /// 大きなコンテンツブロック + 複数行の複合スケルトン。
    /// 生成中ローディング画面などで使用。
    static func contentBlock(
        lines: Int = 5,
        blockHeight: CGFloat = 160,
        useShimmer: Bool = false
    ) -> ScreenshotMatchedSkeleton {
        var bars: [BarSpec] = [
            BarSpec(widthRatio: 0.45, height: 20, cornerRadius: MemoraRadius.sm),
            BarSpec(widthRatio: 1.0, height: blockHeight, cornerRadius: MemoraRadius.xl,
                    color: MemoraColor.skeletonLight),
        ]
        let widths: [CGFloat] = [0.92, 0.78, 0.85, 0.63, 0.88]
        for i in 0..<lines {
            bars.append(
                BarSpec(
                    widthRatio: widths[i % widths.count],
                    height: 14,
                    cornerRadius: MemoraRadius.sm
                )
            )
        }
        return ScreenshotMatchedSkeleton(
            bars: bars,
            spacing: MemoraSpacing.md,
            useShimmer: useShimmer
        )
    }

    /// タイトル + 複数行の基本スケルトン。
    static func titleAndBody(
        bodyLines: Int = 3,
        useShimmer: Bool = false
    ) -> ScreenshotMatchedSkeleton {
        var bars: [BarSpec] = [
            BarSpec(widthRatio: 0.55, height: 22, cornerRadius: MemoraRadius.sm),
        ]
        let widths: [CGFloat] = [0.93, 0.76, 0.88]
        for i in 0..<bodyLines {
            bars.append(
                BarSpec(
                    widthRatio: widths[i % widths.count],
                    height: 14,
                    cornerRadius: MemoraRadius.sm
                )
            )
        }
        return ScreenshotMatchedSkeleton(
            bars: bars,
            spacing: MemoraSpacing.md,
            useShimmer: useShimmer
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Text("Card Skeleton")
                .font(.headline)
            ScreenshotMatchedSkeleton.card()

            Divider()

            Text("Body Lines")
                .font(.headline)
            ScreenshotMatchedSkeleton.bodyLines(count: 4)

            Divider()

            Text("Content Block")
                .font(.headline)
            ScreenshotMatchedSkeleton.contentBlock(lines: 3)

            Divider()

            Text("Title + Body")
                .font(.headline)
            ScreenshotMatchedSkeleton.titleAndBody(bodyLines: 3)

            Divider()

            Text("Individual Bars")
                .font(.headline)
            ScreenshotMatchedSkeleton.Bar(widthRatio: 0.8, height: 44, cornerRadius: 22)
            ScreenshotMatchedSkeleton.Bar(widthRatio: 1.0, height: 120, cornerRadius: 20,
                                          color: MemoraColor.skeletonLight)
        }
        .padding()
    }
    .background(MemoraColor.surfaceBackground)
}
#endif
