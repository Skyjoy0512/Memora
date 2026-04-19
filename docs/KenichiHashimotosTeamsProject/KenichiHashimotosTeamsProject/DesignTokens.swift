// MARK: - Design Tokens
// Centralized design system tokens for consistent styling across the app.

import SwiftUI

enum DesignTokens {
    
    // MARK: - Colors
    
    static let colorBackground = Color(red: 0.945, green: 0.945, blue: 0.945)
    static let colorSelectedTabBackground = Color(red: 0.929, green: 0.929, blue: 0.929)
    static let colorPrimaryText = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let colorSecondaryText = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let colorTertiaryText = Color(red: 0.345, green: 0.345, blue: 0.353)
    static let colorAccent = Color(red: 0, green: 0.365, blue: 0.839)
    static let colorDivider = Color(red: 0.902, green: 0.902, blue: 0.902)
    static let colorWhite = Color.white
    static let colorBlack = Color.black
    
    // MARK: - Typography
    
    static let fontFamily = "SF Pro"
    static let fontSizeLargeTitle: CGFloat = 34
    static let fontSizeBody: CGFloat = 17
    static let fontSizeCaption: CGFloat = 12
    static let fontSizeTabLabel: CGFloat = 10
    
    // MARK: - Spacing
    
    static let spacingExtraSmall: CGFloat = 4
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    
    // MARK: - Sizes
    
    static let buttonSize: CGFloat = 44
    static let iconSizeMedium: CGFloat = 24
    static let iconSizeLarge: CGFloat = 36
    static let tabBarHeight: CGFloat = 62
    static let searchButtonSize: CGFloat = 54
    
    // MARK: - Corner Radius
    
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 100
}
