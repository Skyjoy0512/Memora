import Foundation

extension DateFormatter {
    static let memora = DateFormatterMemora()

    final class DateFormatterMemora {
        private init() {}

        /// ISO8601 フォーマット
        lazy var iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()

        /// 日本語の日付表示
        lazy var japaneseDate: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter
        }()

        /// 日本語の日時表示
        lazy var japaneseDateTime: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter
        }()

        /// 相対日時（今日、昨日など）
        func relativeDate(from date: Date) -> String {
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(date) {
                return "今日"
            } else if calendar.isDateInYesterday(date) {
                return "昨日"
            } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
                return "\(days)日前"
            } else {
                return japaneseDate.string(from: date)
            }
        }
    }
}

extension Date {
    /// 日本語の日付フォーマット
    func formattedDate() -> String {
        DateFormatter.memora.japaneseDate.string(from: self)
    }

    /// 日本語の日時フォーマット
    func formattedDateTime() -> String {
        DateFormatter.memora.japaneseDateTime.string(from: self)
    }

    /// 相対日時フォーマット
    func formattedRelativeDate() -> String {
        DateFormatter.memora.relativeDate(from: self)
    }
}
