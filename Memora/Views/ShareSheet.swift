import SwiftUI

struct ShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareText: String?
    let shareURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("共有")
                    .font(.headline)
                    .padding()

                if let text = shareText {
                    Button(action: { shareText(text) }) {
                        Label("テキストを共有", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .foregroundStyle(.primary)
                }

                if let url = shareURL {
                    Button(action: { shareURL(url) }) {
                        Label("ファイルを共有", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareText(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = scene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func shareURL(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = scene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}
