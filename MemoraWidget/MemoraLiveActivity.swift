import ActivityKit
import WidgetKit
import SwiftUI

struct MemoraLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TranscriptionActivityAttributes.self) { context in
            // Lock screen / Banner presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("文字起こし中")
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "waveform")
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.fileName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "waveform")
            }
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TranscriptionActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                ProgressView(value: context.state.progress)
                    .tint(.blue)
            }

            Spacer()

            Text("\(Int(context.state.progress * 100))%")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
