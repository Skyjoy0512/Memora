import SwiftUI
import AuthenticationServices

struct NotionPagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let token: String
    @Binding var selectedPageID: String
    @Binding var isPresented: Bool

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [NotionService.NotionSearchResult] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.gray)
                        Spacer()
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentRed)
                } else if searchResults.isEmpty {
                    Text("ページが見つかりませんでした")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults, id: \.id) { page in
                        Button {
                            selectedPageID = page.id
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title ?? "（無題）")
                                        .font(MemoraTypography.subheadline)
                                        .foregroundStyle(.primary)

                                    Text(page.type ?? "page")
                                        .font(MemoraTypography.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if page.id == selectedPageID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(MemoraColor.accentBlue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "ページを検索")
            .onChange(of: searchText) { _, newValue in
                Task { await searchNotionPages(query: newValue) }
            }
            .navigationTitle("Notion ページ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
            .task {
                await searchNotionPages(query: "")
            }
        }
    }

    private func searchNotionPages(query: String) async {
        isSearching = true
        errorMessage = nil

        do {
            let service = NotionService()
            searchResults = try await service.searchPages(token: token, query: query)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

// ASWebAuthenticationSession は UIKit の UIWindow を presentation context として
// 必要とするため、UIApplication.shared 経由で activeWindowScene を取得する
final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.activeWindowScene?.windows.first else {
            return UIWindow()
        }
        return window
    }
}
