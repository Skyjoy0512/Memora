import SwiftUI

enum MemoraTypography {
    // MARK: - Heading Scale (Nothing style: bold weight, strong contrast)
    static let largeTitle  = Font.system(.largeTitle, design: .default).bold()
    static let title1      = Font.system(.title, design: .default).bold()
    static let title2      = Font.system(.title2, design: .default).bold()
    static let title3      = Font.system(.title3, design: .default).weight(.semibold)
    static let headline    = Font.system(.headline, design: .default).bold()

    // MARK: - Body Scale (Nothing style: regular/light weight)
    static let body        = Font.system(.body, design: .default)
    static let callout     = Font.system(.callout, design: .default)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let footnote    = Font.system(.footnote, design: .default).weight(.light)
    static let caption1    = Font.system(.caption, design: .default)
    static let caption2    = Font.system(.caption2, design: .default).weight(.light)

    // MARK: - Golden Ratio Scale (Nothing-styled components)
    static let phiCaption   = Font.system(size: 12, weight: .light, design: .default)
    static let phiBody      = Font.system(size: 14, weight: .regular, design: .default)
    static let phiSubhead   = Font.system(size: 17, weight: .medium, design: .default)
    static let phiTitle     = Font.system(size: 21, weight: .bold, design: .default)
    static let phiHeadline  = Font.system(size: 26, weight: .bold, design: .default)
    static let phiDisplay   = Font.system(size: 34, weight: .heavy, design: .default)
}
