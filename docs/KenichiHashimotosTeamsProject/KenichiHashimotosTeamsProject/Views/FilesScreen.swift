import SwiftUI

// MARK: - FilesScreen

/// Main screen displaying a list of audio files with navigation and tab bar.
/// Shows file metadata including date, name, and optional description.
struct FilesScreen: View {
    
    // MARK: - State
    
    @State private var selectedTab: TabItem = .files
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    toolbarSection
                    fileListSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            Spacer()
            
            CustomTabBar(selectedTab: $selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.colorBackground)
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        VStack(spacing: DesignTokens.spacingSmall) {
            HStack {
                Spacer()
                
                HStack(spacing: DesignTokens.spacingSmall) {
                    ToolbarButton(
                        backgroundImage: "refreshButtonBackground",
                        iconImage: "refreshSymbol",
                        accessibilityLabel: "toolbar_refresh_button"
                    ) {
                        // Refresh action
                    }
                    
                    ToolbarButton(
                        backgroundImage: "settingsButtonBackground",
                        iconImage: "settingsSymbol",
                        accessibilityLabel: "toolbar_settings_button"
                    ) {
                        // Settings action
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMedium)
            
            VStack(alignment: .leading) {
                Text("files_title")
                    .font(.custom(DesignTokens.fontFamily, size: DesignTokens.fontSizeLargeTitle))
                    .fontWeight(.bold)
                    .tracking(0.4)
                    .foregroundStyle(DesignTokens.colorPrimaryText)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, DesignTokens.spacingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, DesignTokens.spacingSmall)
    }
    
    // MARK: - File List Section
    
    private var fileListSection: some View {
        VStack(spacing: 0) {
            FileListItem(
                date: "file_date_april_1",
                title: "file_name_mp3",
                description: nil
            )
            
            FileListItem(
                date: "file_date_april_1",
                title: "file_name_engineer_meeting",
                description: "file_description_firebase"
            )
        }
        .padding(.horizontal, DesignTokens.spacingMedium)
    }
}

// MARK: - Preview

#Preview {
    FilesScreen()
}
