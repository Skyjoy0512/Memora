import SwiftUI

struct GlassSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        if let icon {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
