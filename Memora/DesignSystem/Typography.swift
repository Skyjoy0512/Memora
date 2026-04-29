import SwiftUI

enum MemoraTypography {
    // MARK: - Heading Scale
    static let largeTitle  = Font.system(.largeTitle, design: .default).bold()
    static let title1      = Font.system(.title, design: .default).bold()
    static let title2      = Font.system(.title2, design: .default).bold()
    static let title3      = Font.system(.title3, design: .default).weight(.semibold)
    static let headline    = Font.system(.headline, design: .default).bold()

    // MARK: - Body Scale
    static let body        = Font.system(.body, design: .default)
    static let callout     = Font.system(.callout, design: .default)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let footnote    = Font.system(.footnote, design: .default).weight(.light)
    static let caption1    = Font.system(.caption, design: .default)
    static let caption2    = Font.system(.caption2, design: .default).weight(.light)

    // MARK: - Golden Ratio Scale
    static let phiCaption   = Font.system(size: 12, weight: .light, design: .default)
    static let phiBody      = Font.system(size: 14, weight: .regular, design: .default)
    static let phiSubhead   = Font.system(size: 17, weight: .medium, design: .default)
    static let phiTitle     = Font.system(size: 21, weight: .bold, design: .default)
    static let phiHeadline  = Font.system(size: 26, weight: .bold, design: .default)
    static let phiDisplay   = Font.system(size: 34, weight: .bold, design: .default)

    // MARK: - ChatGPT Component Scale (SF Pro-aligned)
    /// Button — large (h44): 14pt Medium
    static let chatButton       = Font.system(size: 14, weight: .medium, design: .default)
    /// Button — small (h36): 13pt Medium
    static let chatButtonSmall  = Font.system(size: 13, weight: .medium, design: .default)
    /// Segmented control — large: 14pt Medium
    static let chatSegment      = Font.system(size: 14, weight: .medium, design: .default)
    /// Segmented control — small: 13pt Medium
    static let chatSegmentSmall = Font.system(size: 13, weight: .medium, design: .default)
    /// Token / chip label: 13pt Regular
    static let chatToken        = Font.system(size: 13, weight: .regular, design: .default)
    /// Section label: 12pt Semibold
    static let chatLabel        = Font.system(size: 12, weight: .semibold, design: .default)
    /// Body text: 14pt Regular
    static let chatBody         = Font.system(size: 14, weight: .regular, design: .default)
    /// Chat message: 15pt Regular
    static let chatMessage      = Font.system(size: 15, weight: .regular, design: .default)
}
