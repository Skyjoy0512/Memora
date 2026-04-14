//
//  MemoraRecordingView.swift
//  DetailsPro Preview
//
//  Memora RecordingView - Recording Screen
//

import SwiftUI

struct MemoraRecordingView: View {
    @State private var recordingTime: TimeInterval = 32.5
    @State private var isRecording = true
    @State private var selectedProject: String? = "プロジェクトA"

    // Waveform animation state
    @State private var waveHeights: [CGFloat] = (0..<20).map { _ in CGFloat.random(in: 10...50) }

    var body: some View {
        VStack(spacing: 0) {
            // Project selector
            HStack {
                Text("プロジェクト:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {} label: {
                    HStack(spacing: 4) {
                        Text(selectedProject ?? "未選択")
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.898, green: 0.898, blue: 0.918).opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .padding(.top, 8)

            Divider()

            // Calendar event suggestion
            Button {} label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("カレンダーから提案")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                        Text("週次定例ミーティング")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(red: 0, green: 0.478, blue: 1).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal)
            .padding(.top, 4)

            VStack(spacing: 21) {
                Spacer()

                // Recording time
                Text(formatTime(recordingTime))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                // Waveform visualization
                HStack(spacing: 5) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isRecording
                                    ? Color(red: 0.898, green: 0.898, blue: 0.918)
                                    : Color(red: 0.898, green: 0.898, blue: 0.918).opacity(0.3)
                            )
                            .frame(width: 4, height: isRecording ? waveHeights[index] : 20)
                            .animation(
                                .easeInOut(duration: 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.02),
                                value: isRecording
                            )
                    }
                }
                .frame(height: 60)

                Spacer()

                // Record button
                Button {
                    isRecording.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.898, green: 0.898, blue: 0.918))
                            .frame(width: 70, height: 70)

                        if isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("録音")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {}
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

#Preview {
    NavigationStack {
        MemoraRecordingView()
    }
}
