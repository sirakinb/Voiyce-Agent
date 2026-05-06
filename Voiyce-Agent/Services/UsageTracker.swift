//
//  UsageTracker.swift
//  Voiyce-Agent
//
//  Persists daily usage stats for dashboard analytics.
//

import Foundation

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    var words: Int
    var dictationSessions: Int

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

@Observable
final class UsageTracker {
    private let defaults = UserDefaults.standard
    private let statsKeyPrefix = "voiyce_daily_"
    private var activeUserID: String?

    func configure(userID: String?) {
        activeUserID = userID
    }

    /// Record words dictated for today.
    func addWords(_ count: Int) {
        var today = loadToday()
        today.words += count
        saveDay(today)
    }

    /// Record a dictation session.
    func addDictationSession() {
        var today = loadToday()
        today.dictationSessions += 1
        saveDay(today)
    }

    /// Get the last 7 days of usage data.
    func weeklyData() -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return loadDay(date)
        }
    }

    /// Today's stats.
    func todayStats() -> DailyUsage {
        return loadToday()
    }

    // MARK: - Persistence

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return statsKeyPrefix + accountScope + "_" + formatter.string(from: date)
    }

    private var accountScope: String {
        guard let activeUserID, !activeUserID.isEmpty else {
            return "signed_out"
        }

        return activeUserID
    }

    private func loadToday() -> DailyUsage {
        loadDay(Calendar.current.startOfDay(for: Date()))
    }

    private func loadDay(_ date: Date) -> DailyUsage {
        let key = dayKey(date)
        if let dict = defaults.dictionary(forKey: key) {
            return DailyUsage(
                date: date,
                words: dict["words"] as? Int ?? 0,
                dictationSessions: dict["dictationSessions"] as? Int ?? 0
            )
        }
        return DailyUsage(date: date, words: 0, dictationSessions: 0)
    }

    private func saveDay(_ usage: DailyUsage) {
        let key = dayKey(usage.date)
        let dict: [String: Int] = [
            "words": usage.words,
            "dictationSessions": usage.dictationSessions
        ]
        defaults.set(dict, forKey: key)
    }

    /// Seed sample data for the past week (for demo purposes).
    func seedSampleDataIfEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Only seed if today has no data
        let todayKey = dayKey(today)
        guard defaults.dictionary(forKey: todayKey) == nil else { return }

        let sampleWords = [320, 580, 210, 890, 450, 670, 0]
        let sampleDictation = [5, 9, 3, 15, 7, 11, 0]

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let usage = DailyUsage(
                date: date,
                words: sampleWords[i],
                dictationSessions: sampleDictation[i]
            )
            saveDay(usage)
        }
    }
}
