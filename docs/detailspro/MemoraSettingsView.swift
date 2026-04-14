//
//  MemoraSettingsView.swift
//  DetailsPro Preview
//
//  Memora SettingsView - Settings Screen
//

import SwiftUI

struct MemoraSettingsView: View {
    @State private var transcriptionMode = 0
    @State private var selectedProvider = 0
    @State private var apiKey = "sk-••••••••••••••••"
    @State private var plaudEnabled = false
    @State private var notionEnabled = true

    var body: some View {
        NavigationStack {
            List {
                // Transcription Settings
                Section("文字起こし設定") {
                    Picker("文字起こしモード", selection: $transcriptionMode) {
                        Text("ローカル").tag(0)
                        Text("API").tag(1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                            Text("ローカル文字起こしは SFSpeechRecognizer を使用します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("インターネット接続不要・無料で利用できます")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                    }
                    .padding(.vertical, 2)

                    // STT Diagnostics link
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STT 診断")
                                .font(.subheadline)
                            Text("backend 状態、asset 状態を確認")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // AI Provider
                Section("AI プロバイダー選択") {
                    Picker("プロバイダー", selection: $selectedProvider) {
                        Text("OpenAI").tag(0)
                        Text("Gemini").tag(1)
                        Text("DeepSeek").tag(2)
                        Text("Local").tag(3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("選択中のプロバイダー:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("OpenAI")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("料金目安:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("• API文字起こし: $0.006 / 分")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("• 要約: $0.00015 / 1K tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                // API Key
                Section("API キー設定") {
                    SecureField("API キー", text: $apiKey)
                        .textFieldStyle(.plain)
                    Text("API キーが設定されています")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                }

                // Memory Settings
                Section("Memory") {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Memory 設定")
                                .font(.subheadline)
                            Text("12 件保存・標準")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Profile")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0, green: 0.478, blue: 1).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                }

                // Integrations
                Section("連携") {
                    Toggle("Notion 連携を有効化", isOn: $notionEnabled)

                    if notionEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                            Text("設定完了")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.204, green: 0.78, blue: 0.349))
                        }
                    }

                    Toggle("Plaud 連携を有効化", isOn: $plaudEnabled)
                }

                // Omi Connection
                Section("Omi 接続") {
                    VStack(spacing: 13) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))

                        Text("デバイスが見つかりませんでした")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {} label: {
                            Label("再スキャン", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color(red: 0.898, green: 0.898, blue: 0.918))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Developer Features
                Section("開発者機能") {
                    HStack {
                        Image(systemName: "flask")
                            .foregroundStyle(.purple)
                        Text("Gemma 4 実験プロファイル")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                        Text("Plaud エクスポートインポート")
                            .font(.subheadline)
                    }
                }

                // Debug
                Section("デバッグ") {
                    HStack {
                        Image(systemName: "ladybug")
                            .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
                        Text("デバッグログ")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }

                // Data Management
                Section("データ管理") {
                    Button {} label: {
                        Text("API キーを削除")
                            .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MemoraSettingsView()
}
