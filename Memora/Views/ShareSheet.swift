import SwiftUI
import SwiftData

// MARK: - UIApplication Helper

/// UIKit コンポーネント（UIActivityViewController, ASWebAuthenticationSession など）の
/// 表示には UIWindowScene への参照が必須。SwiftUI の @Environment(\.scenePhase) では
/// この参照を取得できないため、UIApplication.shared 経由で取得する。
extension UIApplication {
    /// 接続中のシーンから最初の UIWindowScene を返す。
    /// UIActivityViewController / ASWebAuthenticationSession の
    /// presentation context 取得に使用する。
    var activeWindowScene: UIWindowScene? {
        connectedScenes.first as? UIWindowScene
    }
}

struct ShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let shareText: String?
    let shareURL: URL?
    let audioFile: AudioFile
    @State private var showExportOptions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: MemoraSpacing.lg) {
                Text("共有")
                    .font(MemoraTypography.headline)
                    .padding()

                // エクスポートボタン
                Button(action: { showExportOptions = true }) {
                    Label("エクスポート", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MemoraColor.divider.opacity(0.1))
                        .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                }
                .foregroundStyle(.primary)

                if let text = shareText {
                    Button(action: { shareText(text) }) {
                        Label("テキストを共有", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MemoraColor.divider.opacity(0.1))
                            .clipShape(.rect(cornerRadius: MemoraRadius.sm))
                    }
                    .foregroundStyle(.primary)
                }

                if let url = shareURL {
                    Button(action: { shareURL(url) }) {
                        Label("ファイルを共有", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MemoraColor.divider.opacity(0.1))
                            .clipShape(.rect(cornerRadius: MemoraRadius.sm))
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
            .sheet(isPresented: $showExportOptions) {
                ExportOptionsSheet(audioFile: audioFile)
            }
        }
    }

    // UIActivityViewController は UIKit コンポーネントのため
    // UIWindowScene 経由で rootViewController を取得する必要がある
    private func shareText(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let rootViewController = UIApplication.shared.activeWindowScene?.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func shareURL(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let rootViewController = UIApplication.shared.activeWindowScene?.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}
