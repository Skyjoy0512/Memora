import SwiftUI

struct ThinkingDots: View {
    @State private var activeDot = -1
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(activeDot == index ? MemoraColor.accentNothing : MemoraColor.accentNothingSubtle)
                    .frame(width: activeDot == index ? 12 : 10, height: activeDot == index ? 12 : 10)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
                    .nothingGlow(activeDot == index ? .subtle : .init(color: .clear, radius: 0, intensity: 0, animated: false))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: activeDot)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            animationTask = Task {
                while !Task.isCancelled {
                    for i in 0..<3 {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        withAnimation { activeDot = i }
                    }
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }
}
