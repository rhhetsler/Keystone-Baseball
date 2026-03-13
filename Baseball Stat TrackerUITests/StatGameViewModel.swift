import Foundation
import SwiftData

@Model
final class SavedGame {
    var id: UUID
    var savedAt: Date
    var title: String
    var payload: Data

    init(id: UUID = UUID(), savedAt: Date = Date(), title: String, payload: Data) {
        self.id = id
        self.savedAt = savedAt
        self.title = title
        self.payload = payload
    }
}

enum HalfInning: String, Codable {
    case top
    case bottom
}

struct InningStats: Codable, Hashable {
    var runs: Int = 0

    // charged to FIELDING team
    var walksAllowed: Int = 0
    var hbpAllowed: Int = 0
    var errors: Int = 0
    var passedBall: Int = 0
    var wildPitch: Int = 0
    var balk: Int = 0
    var stolenBasesAgainst: Int = 0
    var otherFreeBase: Int = 0

    // charged to BATTING team
    var strikeOutsBatting: Int = 0

    var mistakesTotal: Int {
        walksAllowed + hbpAllowed + errors + passedBall + wildPitch + balk +
        stolenBasesAgainst + otherFreeBase + strikeOutsBatting
    }
}

struct GameSavePayload: Codable {
    var savedAt: Date
    var homeName: String
    var awayName: String
    var inning: Int
    var half: HalfInning
    var outs: Int
    var homeStats: [InningStats]
    var awayStats: [InningStats]
}
