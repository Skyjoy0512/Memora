import SwiftUI

// MARK: - Tone

enum STTDiagnosticsTone {
    case success
    case warning
    case neutral

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .success:
            return MemoraColor.accentGreen
        case .warning:
            return .orange
        case .neutral:
            return MemoraColor.textSecondary
        }
    }

    var background: Color {
        switch self {
        case .success:
            return MemoraColor.accentGreen.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.12)
        case .neutral:
            return MemoraColor.divider.opacity(0.18)
        }
    }
}

// MARK: - Panel

struct STTDiagnosticsPanel {
    let title: String
    let badgeText: String
    let tone: STTDiagnosticsTone
    let summary: String
    let details: [String]
}

// MARK: - Card

struct STTDiagnosticsCard: View {
    let panel: STTDiagnosticsPanel

    init(_ panel: STTDiagnosticsPanel) {
        self.panel = panel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(panel.title)
                        .font(MemoraTypography.subheadline)
                        .fontWeight(.semibold)

                    Text(panel.summary)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(panel.badgeText, systemImage: panel.tone.iconName)
                    .font(MemoraTypography.caption1)
                    .padding(.horizontal, MemoraSpacing.xs)
                    .padding(.vertical, 6)
                    .background(panel.tone.background)
                    .clipShape(Capsule())
                    .foregroundStyle(panel.tone.tint)
            }

            ForEach(panel.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: MemoraSpacing.xs) {
                    Circle()
                        .fill(MemoraColor.textTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)

                    Text(detail)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
    }
}
