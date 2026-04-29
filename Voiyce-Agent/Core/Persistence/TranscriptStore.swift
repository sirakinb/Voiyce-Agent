//
//  TranscriptStore.swift
//  Voiyce-Agent
//

import SwiftData
import Foundation

@Model
final class Transcript {
    var id: UUID
    var text: String
    var date: Date
    var appName: String
    var wordCount: Int
    var duration: TimeInterval

    init(text: String, appName: String, duration: TimeInterval = 0) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.appName = appName
        self.wordCount = text.split(separator: " ").count
        self.duration = duration
    }
}
