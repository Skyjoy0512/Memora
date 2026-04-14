//
//  MemoraProjectDetailView.swift
//  DetailsPro Preview
//
//  Memora ProjectDetailView - Project Detail Screen
//

import SwiftUI

struct MemoraProjectDetailView: View {
    @State private var projectName: String = "プロジェクトA"

    private let projectFiles: [ProjectFileItem] = [
        ProjectFileItem(title: "週次定例ミーティング", date: "04/14 10:00", duration: "45:30", isTranscribed: true, isSummarized: true),
        ProjectFileItem(title: "デザインレビュー", date: "04/11 11:00", duration: "25:08", isTranscribed: true, isSummarized: true),
        ProjectFileItem(title: "仕様確認 MTG", date: "04/09 15:00", duration: "38:15", isTranscribed: true, isSummarized: false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Project photo section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("プロジェクト写真", systemImage: "photo.stack")
                            .font(.headline)
                        Text("資料や現場写真をこのプロジェクトに残せます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {} label: {
                        Label("追加", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.898, green: 0.898, blue: 0.918).opacity(0.3),
                                                Color(red: 0.898, green: 0.898, blue: 0.918).opacity(0.6)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 132, height: 98)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                                    }
                                Text(["ホワイトボード", "会議室", "資料", "メモ"][index])
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.118))
                                    .lineLimit(1)
                            }
                            .frame(width: 132, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)

            Divider()

            // File list
            List {
                Section("録音") {
                    ForEach(projectFiles) { file in
                        ProjectFileRow(file: file)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {} label: {
                    Image(systemName: "photo.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {} label: {
                    Image(systemName: "mic")
                }
            }
        }
    }
}

// MARK: - Project File Item

struct ProjectFileItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let duration: String
    let isTranscribed: Bool
    let isSummarized: Bool
}

// MARK: - Project File Row

struct ProjectFileRow: View {
    let file: ProjectFileItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(file.title)
                .font(.body)
                .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.118))
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(file.date)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                Text(file.duration)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            }

            HStack(spacing: 4) {
                Spacer()
                if file.isTranscribed {
                    Text("文字起こし済")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0, green: 0.478, blue: 1).opacity(0.12))
                        .clipShape(Capsule())
                }
                if file.isSummarized {
                    Text("要約済")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.204, green: 0.78, blue: 0.349).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MemoraProjectDetailView()
    }
}
