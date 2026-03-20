import Foundation

extension TimeInterval {
    /// 秒数を読みやすいフォーマットに変換
    /// - Returns: "MM:SS" または "H:MM:SS" 形式の文字列
    func formattedDuration() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// 秒数を詳細なフォーマットに変換
    /// - Returns: "X時間Y分" または "X分Y秒" 形式の文字列
    func formattedDurationLong() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}
