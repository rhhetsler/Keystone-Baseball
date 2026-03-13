import Foundation
import SwiftData

@Model
final class SavedGame {
    var id: UUID
    var date: Date

    // Basic game info
    var opponent: String
    var location: String
    var innings: Int

    // Simple score (add more stats whenever)
    var runsFor: Int
    var runsAgainst: Int

    init(
        date: Date = .now,
        opponent: String = "",
        location: String = "",
        innings: Int = 7,
        runsFor: Int = 0,
        runsAgainst: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.opponent = opponent
        self.location = location
        self.innings = innings
        self.runsFor = runsFor
        self.runsAgainst = runsAgainst
    }
}
