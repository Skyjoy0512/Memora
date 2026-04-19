import SwiftUI

// MARK: - TabItem

/// Enum representing available tab items in the tab bar.
enum TabItem: String, CaseIterable {
    case files
    case project
    case todo
    case settings
    
    var iconName: String {
        switch self {
        case .files: return "filesTabIcon"
        case .project: return "projectTabIcon"
        case .todo: return "todoTabIcon"
        case .settings: return "settingsTabIcon"
        }
    }
    
    var titleKey: String {
        switch self {
        case .files: return "tab_files"
        case .project: return "tab_project"
        case .todo: return "tab_todo"
        case .settings: return "tab_settings"
        }
    }
}

// MARK: - CustomTabBar

/// Custom tab bar with four tabs and a floating search button.
/// - Parameter selectedTab: Binding to the currently selected tab
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingMedium) {
            tabBarItems
            searchButton
        }
        .padding(.top, DesignTokens.spacingMedium)
        .padding(.bottom, DesignTokens.spacingLarge)
        .padding(.horizontal, DesignTokens.spacingLarge)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.colorBackground)
    }
    
    // MARK: - Tab Bar Items
    
    private var tabBarItems: some View {
        ZStack {
            Image("tabBarBackground")
                .resizable()
                .frame(height: DesignTokens.tabBarHeight)
                .accessibilityHidden(true)
            
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingSmall)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Search Button
    
    private var searchButton: some View {
        Button(action: {
            // Search action
        }) {
            ZStack {
                Image("searchButtonBackground")
                    .resizable()
                    .frame(width: DesignTokens.searchButtonSize, height: DesignTokens.searchButtonSize)
                    .accessibilityHidden(true)
                
                Image("searchIcon")
                    .resizable()
                    .frame(width: DesignTokens.iconSizeMedium, height: DesignTokens.iconSizeMedium)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: DesignTokens.searchButtonSize, height: DesignTokens.searchButtonSize)
        .accessibilityLabel(Text("search_button"))
    }
}

// MARK: - TabBarItem

/// Individual tab bar item with icon and label.
struct TabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.spacingExtraSmall) {
                Image(tab.iconName)
                    .resizable()
                    .frame(width: DesignTokens.iconSizeMedium, height: DesignTokens.iconSizeMedium)
                    .accessibilityHidden(true)
                
                Text(LocalizedStringKey(tab.titleKey))
                    .font(.custom(DesignTokens.fontFamily, size: DesignTokens.fontSizeTabLabel))
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? DesignTokens.colorAccent : DesignTokens.colorPrimaryText)
            }
            .padding(.vertical, DesignTokens.spacingSmall)
            .padding(.horizontal, DesignTokens.spacingSmall)
            .background(
                isSelected ? DesignTokens.colorSelectedTabBackground : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge))
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(LocalizedStringKey(tab.titleKey)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(.files))
}
