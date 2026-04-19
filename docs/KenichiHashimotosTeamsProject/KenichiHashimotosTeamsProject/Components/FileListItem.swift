import SwiftUI

// MARK: - FileListItem

/// A list item displaying file information with date, title, and optional description.
/// - Parameters:
///   - date: Localization key for the date string
///   - title: Localization key for the file title
///   - description: Optional localization key for the file description
struct FileListItem: View {
    let date: String
    let title: String
    let description: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingExtraSmall) {
                Text(LocalizedStringKey(date))
                    .font(.custom(DesignTokens.fontFamily, size: DesignTokens.fontSizeCaption))
                    .tracking(-0.43)
                    .foregroundStyle(DesignTokens.colorSecondaryText)
                
                Text(LocalizedStringKey(title))
                    .font(.custom(DesignTokens.fontFamily, size: DesignTokens.fontSizeBody))
                    .tracking(-0.43)
                    .foregroundStyle(DesignTokens.colorPrimaryText)
                
                if let description = description {
                    Text(LocalizedStringKey(description))
                        .font(.custom(DesignTokens.fontFamily, size: DesignTokens.fontSizeCaption))
                        .tracking(-0.23)
                        .foregroundStyle(DesignTokens.colorTertiaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.spacingSmall)
            
            Divider()
                .background(DesignTokens.colorDivider)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack {
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
    .padding()
}
