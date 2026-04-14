//
//  MemoraHomeView.swift
//  DetailsPro Preview
//
//  Memora HomeView - Files List Screen
//  このコードをDetailsProに貼り付けてプレビューできます
//

import SwiftUI

// MARK: - Design Tokens

enum MemoraColor {
    static let surfacePrimary   = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let surfaceSecondary = Color.white
    static let accentBlue       = Color(red: 0, green: 0.478, blue: 1)
    static let accentRed        = Color(red: 1, green: 0.231, blue: 0.188)
    static let accentGreen      = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let textPrimary      = Color(red: 0.11, green: 0.11, blue: 0.118)
    static let textSecondary    = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let textTertiary     = Color(red: 0.682, green: 0.682, blue: 0.698)
    static let divider          = Color(red: 0.898, green: 0.898, blue: 0.918)
}

enum MemoraSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat  = 4
    static let xs: CGFloat   = 8
    static let sm: CGFloat   = 12
    static let md: CGFloat   = 16
    static let lg: CGFloat   = 20
    static let xl: CGFloat   = 24
    static let xxl: CGFloat  = 32
}

enum MemoraRadius {
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 13
    static let lg: CGFloat  = 16
}

// MARK: - Sample Data

struct SampleAudioFile: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let duration: String
    let source: String
    let sourceIcon: String
    let project: String?
    let isTranscribed: Bool
    let isSummarized: Bool
}

// MARK: - HomeView

struct MemoraHomeView: View {
    @State private var searchText = ""
    @State private var isSelectMode = false

    private let sampleFiles: [SampleAudioFile] = [
        SampleAudioFile(
            title: "週次定例ミーティング",
            date: "04/14 10:00",
            duration: "45:30",
            source: "録音",
            sourceIcon: "mic.fill",
            project: "プロジェクトA",
            isTranscribed: true,
            isSummarized: true
        ),
        SampleAudioFile(
            title: "クライアント要件ヒアリング",
            date: "04/13 14:30",
            duration: "32:15",
            source: "Meet",
            sourceIcon: "video.fill",
            project: "プロジェクトB",
            isTranscribed: true,
            isSummarized: false
        ),
        SampleAudioFile(
            title: "アイデアブレインストーミング",
            date: "04/12 16:00",
            duration: "18:42",
            source: "録音",
            sourceIcon: "mic.fill",
            project: nil,
            isTranscribed: false,
            isSummarized: false
        ),
        SampleAudioFile(
            title: "デザインレビュー",
            date: "04/11 11:00",
            duration: "25:08",
            source: "Plaud",
            sourceIcon: "waveform",
            project: "プロジェクトA",
            isTranscribed: true,
            isSummarized: true
        ),
        SampleAudioFile(
            title: "技術選定ディスカッション",
            date: "04/10 09:30",
            duration: "55:12",
            source: "インポート",
            sourceIcon: "square.and.arrow.down",
            project: nil,
            isTranscribed: true,
            isSummarized: false
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                // Active filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MemoraSpacing.xs) {
                        FilterChip(title: "文字起こし済", isSelected: true) {}
                        FilterChip(title: "プロジェクトA", isSelected: true) {}
                    }
                    .padding(.horizontal, MemoraSpacing.sm)
                    .padding(.vertical, MemoraSpacing.xxxs)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

                // File list
                ForEach(sampleFiles) { file in
                    AudioFileRowDesign(file: file)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: MemoraSpacing.xs, leading: MemoraSpacing.md, bottom: MemoraSpacing.xs, trailing: MemoraSpacing.md))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MemoraColor.surfacePrimary)
            .searchable(text: $searchText, placement: .toolbar, prompt: "ファイルを検索")
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {} label: {
                            Label("録音", systemImage: "mic.fill")
                        }
                        Button {} label: {
                            Label("インポート", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                AskAIFloatingButton {}
            }
        }
    }
}

// MARK: - Audio File Row

struct AudioFileRowDesign: View {
    let file: SampleAudioFile

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
            // Title
            Text(file.title)
                .font(.body)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(1)

            // Date + Duration + Source
            HStack(spacing: MemoraSpacing.xs) {
                Text(file.date)
                    .font(.caption)
                    .foregroundStyle(MemoraColor.textSecondary)

                Text(file.duration)
                    .font(.caption)
                    .foregroundStyle(MemoraColor.textSecondary)

                Image(systemName: file.sourceIcon)
                    .font(.caption2)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            // Project + Status Chips
            HStack(spacing: MemoraSpacing.xxs) {
                if let project = file.project {
                    Label(project, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if file.isTranscribed {
                    StatusChipDesign(title: "文字起こし済", color: MemoraColor.accentBlue)
                }
                if file.isSummarized {
                    StatusChipDesign(title: "要約済", color: MemoraColor.accentGreen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MemoraSpacing.sm)
        .padding(.horizontal, MemoraSpacing.md)
        .background(MemoraColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MemoraRadius.md))
    }
}

// MARK: - Status Chip

struct StatusChipDesign: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: MemoraSpacing.xxxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(MemoraColor.accentBlue)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(MemoraColor.accentBlue)
            }
        }
        .padding(.horizontal, MemoraSpacing.sm)
        .padding(.vertical, MemoraSpacing.xxs)
        .background(MemoraColor.accentBlue.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Ask AI Floating Button

struct AskAIFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MemoraSpacing.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .medium))
                Text("Ask AI")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, MemoraSpacing.md)
            .padding(.vertical, MemoraSpacing.sm)
            .background(MemoraColor.accentBlue)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .padding(.trailing, MemoraSpacing.md)
        .padding(.bottom, MemoraSpacing.lg)
    }
}

#Preview {
    MemoraHomeView()
}
