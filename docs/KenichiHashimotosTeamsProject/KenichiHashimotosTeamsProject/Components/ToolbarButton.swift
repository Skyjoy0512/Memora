import SwiftUI

// MARK: - ToolbarButton

/// A circular toolbar button with background image and icon.
/// - Parameters:
///   - backgroundImage: Name of the background image asset
///   - iconImage: Name of the icon image asset
///   - accessibilityLabel: Localization key for accessibility
///   - action: Closure executed on tap
struct ToolbarButton: View {
    let backgroundImage: String
    let iconImage: String
    let accessibilityLabel: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Image(backgroundImage)
                    .resizable()
                    .frame(width: DesignTokens.buttonSize, height: DesignTokens.buttonSize)
                    .accessibilityHidden(true)
                
                Image(iconImage)
                    .resizable()
                    .frame(width: DesignTokens.iconSizeLarge, height: DesignTokens.iconSizeLarge)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: DesignTokens.buttonSize, height: DesignTokens.buttonSize)
        .clipShape(Circle())
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
    }
}

#Preview {
    HStack {
        ToolbarButton(
            backgroundImage: "refreshButtonBackground",
            iconImage: "refreshSymbol",
            accessibilityLabel: "toolbar_refresh_button"
        ) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
