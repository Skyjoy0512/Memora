import Testing
import Foundation
@testable import Memora

// MARK: - STT Deadline Tests (PR-E1)

/// NSLock ラッパー（テスト用のスレッドセーフな状態保持）
private final class LockedBox<T> {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    func get() -> T { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ value: T) { lock.lock(); defer { lock.unlock() }; self.value = value }
    func mutate(_ body: (inout T) -> Void) {
        lock.lock()
        body(&value)
        lock.unlock()
    }
}

struct STTDeadlineTests {

    @Test("即時成功は値を返す")
    func immediateSuccess() async throws {
        let value = try await withDeadline(seconds: 5) { 42 }
        #expect(value == 42)
    }

    @Test("期限超過は DeadlineExceededError を投げる")
    func deadlineExceeded() async {
        do {
            _ = try await withDeadline(seconds: 0.1) {
                try? await Task.sleep(for: .milliseconds(400))
                return 1
            }
            Issue.record("should throw")
        } catch {
            #expect(error is DeadlineExceededError)
        }
        // 遅延完了が resume を試みる時間まで待つ（double-resume なら fatal）
        try? await Task.sleep(for: .milliseconds(600))
    }

    @Test("期限超過後もクラッシュしない（遅延完了の破棄）")
    func lateCompletionDiscarded() async {
        let completed = LockedBox(false)
        _ = try? await withDeadline(seconds: 0.1) {
            try? await Task.sleep(for: .milliseconds(400))
            completed.set(true)
            return 1
        }
        try? await Task.sleep(for: .milliseconds(500))
        // クラッシュせずここまで到達すれば OK
        #expect(Bool(true))
    }

    @Test("onDeadline フックがタイムアウト時に1回だけ呼ばれる")
    func onDeadlineHookInvokedOnce() async {
        let count = LockedBox(0)
        _ = try? await withDeadline(
            seconds: 0.1,
            onDeadline: { count.mutate { $0 += 1 } }
        ) {
            try? await Task.sleep(for: .seconds(1))
            return 0
        }
        try? await Task.sleep(for: .milliseconds(200))
        #expect(count.get() == 1)
    }

    @Test("onDeadline フックは通常完了時には呼ばれない")
    func onDeadlineNotCalledOnSuccess() async throws {
        let count = LockedBox(0)
        let value = try await withDeadline(
            seconds: 5,
            onDeadline: { count.mutate { $0 += 1 } }
        ) { 99 }
        #expect(value == 99)
        #expect(count.get() == 0)
    }
}
