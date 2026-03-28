import SwiftUI

enum MemoraTypography {
    static let largeTitle  = Font.system(.largeTitle, design: .default).bold()
    static let title1      = Font.system(.title, design: .default).weight(.semibold)
    static let title2      = Font.system(.title2, design: .default).weight(.semibold)
    static let title3      = Font.system(.title3, design: .default).weight(.medium)
    static let headline    = Font.system(.headline, design: .default).weight(.semibold)
    static let body        = Font.system(.body, design: .default)
    static let callout     = Font.system(.callout, design: .default)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let footnote    = Font.system(.footnote, design: .default)
    static let caption1    = Font.system(.caption, design: .default)
    static let caption2    = Font.system(.caption2, design: .default)
}
