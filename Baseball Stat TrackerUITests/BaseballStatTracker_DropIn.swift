import SwiftUI
import SwiftData
import Foundation

// MARK: - App

@main
struct Baseball_Stat_TrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SavedGame.self, PlayerLine.self, GameEvent.self])
    }
}

// MARK: - SwiftData Models

@Model
final class SavedGame {
    var id: UUID
    var createdAt: Date

    // Game info
    var date: Date
    var opponent: String
    var location: String
    var inningsScheduled: Int

    // Team names (optional)
    var homeTeamName: String
    var awayTeamName: String
    var isHome: Bool

    // Score
    var runsFor: Int
    var runsAgainst: Int
    var hitsFor: Int
    var hitsAgainst: Int
    var errorsFor: Int
    var errorsAgainst: Int

    // Situational / “coach review” team totals
    var strikeoutsLooking: Int
    var strikeoutsSwinging: Int
    var walks: Int
    var hitByPitch: Int
    var sacFlies: Int
    var sacBunts: Int
    var stolenBases: Int
    var caughtStealing: Int
    var wildPitches: Int
    var passedBalls: Int
    var balks: Int

    // Notes
    var notes: String

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \PlayerLine.game)
    var playerLines: [PlayerLine]

    @Relationship(deleteRule: .cascade, inverse: \GameEvent.game)
    var events: [GameEvent]

    init(
        date: Date = .now,
        opponent: String = "",
        location: String = "",
        inningsScheduled: Int = 7,
        homeTeamName: String = "Our Team",
        awayTeamName: String = "",
        isHome: Bool = true
    ) {
        self.id = UUID()
        self.createdAt = .now

        self.date = date
        self.opponent = opponent
        self.location = location
        self.inningsScheduled = inningsScheduled

        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.isHome = isHome

        self.runsFor = 0
        self.runsAgainst = 0
        self.hitsFor = 0
        self.hitsAgainst = 0
        self.errorsFor = 0
        self.errorsAgainst = 0

        self.strikeoutsLooking = 0
        self.strikeoutsSwinging = 0
        self.walks = 0
        self.hitByPitch = 0
        self.sacFlies = 0
        self.sacBunts = 0
        self.stolenBases = 0
        self.caughtStealing = 0
        self.wildPitches = 0
        self.passedBalls = 0
        self.balks = 0

        self.notes = ""

        self.playerLines = []
        self.events = []
    }
}

@Model
final class PlayerLine {
    var id: UUID
    var createdAt: Date

    // Link back to game
    var game: SavedGame?

    // Player identity
    var playerName: String
    var jerseyNumber: String
    var primaryPosition: String

    // Batting line
    var plateAppearances: Int
    var atBats: Int
    var runs: Int
    var hits: Int
    var doubles: Int
    var triples: Int
    var homeRuns: Int
    var rbi: Int
    var walks: Int
    var hitByPitch: Int
    var strikeoutsSwinging: Int
    var strikeoutsLooking: Int
    var sacFlies: Int
    var sacBunts: Int
    var stolenBases: Int
    var caughtStealing: Int

    // Fielding
    var putouts: Int
    var assists: Int
    var errors: Int
    var passedBalls: Int // catcher only, if desired
    var pitcherPickoffs: Int

    // Pitching line
    var pitched: Bool
    var outsRecorded: Int // store as outs so we can do thirds cleanly
    var hitsAllowed: Int
    var runsAllowed: Int
    var earnedRunsAllowed: Int
    var walksAllowed: Int
    var strikeoutsPitched: Int
    var hitBatters: Int
    var wildPitches: Int
    var balks: Int

    init(
        playerName: String,
        jerseyNumber: String = "",
        primaryPosition: String = ""
    ) {
        self.id = UUID()
        self.createdAt = .now

        self.playerName = playerName
        self.jerseyNumber = jerseyNumber
        self.primaryPosition = primaryPosition

        self.plateAppearances = 0
        self.atBats = 0
        self.runs = 0
        self.hits = 0
        self.doubles = 0
        self.triples = 0
        self.homeRuns = 0
        self.rbi = 0
        self.walks = 0
        self.hitByPitch = 0
        self.strikeoutsSwinging = 0
        self.strikeoutsLooking = 0
        self.sacFlies = 0
        self.sacBunts = 0
        self.stolenBases = 0
        self.caughtStealing = 0

        self.putouts = 0
        self.assists = 0
        self.errors = 0
        self.passedBalls = 0
        self.pitcherPickoffs = 0

        self.pitched = false
        self.outsRecorded = 0
        self.hitsAllowed = 0
        self.runsAllowed = 0
        self.earnedRunsAllowed = 0
        self.walksAllowed = 0
        self.strikeoutsPitched = 0
        self.hitBatters = 0
        self.wildPitches = 0
        self.balks = 0
    }

    // MARK: Computed (Review)
    var battingAverage: String {
        guard atBats > 0 else { return ".---" }
        let avg = Double(hits) / Double(atBats)
        return String(format: "%.3f", avg).replacingOccurrences(of: "0.", with: ".")
    }

    var onBasePercentage: String {
        // OBP = (H + BB + HBP) / (AB + BB + HBP + SF)
        let denom = atBats + walks + hitByPitch + sacFlies
        guard denom > 0 else { return ".---" }
        let obp = Double(hits + walks + hitByPitch) / Double(denom)
        return String(format: "%.3f", obp).replacingOccurrences(of: "0.", with: ".")
    }

    var slugging: String {
        // SLG = TB / AB
        guard atBats > 0 else { return ".---" }
        let singles = max(0, hits - doubles - triples - homeRuns)
        let totalBases = singles + (2 * doubles) + (3 * triples) + (4 * homeRuns)
        let slg = Double(totalBases) / Double(atBats)
        return String(format: "%.3f", slg).replacingOccurrences(of: "0.", with: ".")
    }

    var inningsPitchedDisplay: String {
        // outs -> innings.thirds
        let innings = outsRecorded / 3
        let thirds = outsRecorded % 3
        return "\(innings).\(thirds)"
    }

    var eraDisplay: String {
        // ERA = (ER * 9) / IP ; IP in innings (outs/3)
        let ip = Double(outsRecorded) / 3.0
        guard ip > 0 else { return "--.--" }
        let era = (Double(earnedRunsAllowed) * 9.0) / ip
        return String(format: "%.2f", era)
    }
}

enum EventType: String, CaseIterable, Identifiable, Codable {
    case note = "Note"
    case error = "Error"
    case wildPitch = "Wild Pitch"
    case passedBall = "Passed Ball"
    case stolenBase = "Stolen Base"
    case caughtStealing = "Caught Stealing"
    case balk = "Balk"
    case pitchingChange = "Pitching Change"
    case bigPlay = "Big Play"
    case injury = "Injury"

    var id: String { rawValue }
}

@Model
final class GameEvent {
    var id: UUID
    var createdAt: Date

    var game: SavedGame?

    var typeRaw: String
    var inning: Int
    var isTop: Bool
    var detail: String

    init(type: EventType, inning: Int, isTop: Bool, detail: String) {
        self.id = UUID()
        self.createdAt = .now
        self.typeRaw = type.rawValue
        self.inning = inning
        self.isTop = isTop
        self.detail = detail
    }

    var type: EventType {
        EventType(rawValue: typeRaw) ?? .note
    }

    var inningDisplay: String {
        "\(isTop ? "Top" : "Bot") \(inning)"
    }
}

// MARK: - Root View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedGame.createdAt, order: .reverse) private var games: [SavedGame]

    @State private var showingNewGame = false

    var body: some View {
        NavigationStack {
            List {
                if games.isEmpty {
                    ContentUnavailableView("No games yet", systemImage: "baseball.fill", description: Text("Tap Add to start tracking a game."))
                } else {
                    ForEach(games) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.opponent.isEmpty ? "Opponent TBD" : "vs \(game.opponent)")
                                    .font(.headline)
                                Text("\(game.date.formatted(date: .abbreviated, time: .omitted)) • \(game.location.isEmpty ? "Location TBD" : game.location)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Final/Current: \(game.runsFor) - \(game.runsAgainst)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteGames)
                }
            }
            .navigationTitle("Games")
            .toolbar {
                Button {
                    showingNewGame = true
                } label: {
                    Label("Add Game", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingNewGame) {
                NewGameSheet { newGame in
                    modelContext.insert(newGame)
                }
            }
        }
    }

    private func deleteGames(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(games[index])
        }
    }
}

// MARK: - New Game

struct NewGameSheet: View {
    var onCreate: (SavedGame) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = .now
    @State private var opponent: String = ""
    @State private var location: String = ""
    @State private var inningsScheduled: Int = 7
    @State private var isHome: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Info") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Opponent", text: $opponent)
                    TextField("Location", text: $location)

                    Stepper("Scheduled Innings: \(inningsScheduled)", value: $inningsScheduled, in: 1...14)
                    Toggle("We are Home", isOn: $isHome)
                }

                Section {
                    Button {
                        let g = SavedGame(
                            date: date,
                            opponent: opponent,
                            location: location,
                            inningsScheduled: inningsScheduled,
                            homeTeamName: "Our Team",
                            awayTeamName: opponent,
                            isHome: isHome
                        )
                        onCreate(g)
                        dismiss()
                    } label: {
                        Text("Create Game")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Game Detail / Review

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var game: SavedGame

    @State private var showingAddPlayer = false
    @State private var showingQuickEvent = false

    var body: some View {
        List {
            Section("Score & Team Totals") {
                HStack {
                    StatStepper(title: "Runs For", value: $game.runsFor)
                    StatStepper(title: "Runs Against", value: $game.runsAgainst)
                }
                HStack {
                    StatStepper(title: "Hits For", value: $game.hitsFor)
                    StatStepper(title: "Hits Against", value: $game.hitsAgainst)
                }
                HStack {
                    StatStepper(title: "Errors For", value: $game.errorsFor)
                    StatStepper(title: "Errors Against", value: $game.errorsAgainst)
                }

                DisclosureGroup("Discipline / Situational") {
                    HStack {
                        StatStepper(title: "BB", value: $game.walks)
                        StatStepper(title: "HBP", value: $game.hitByPitch)
                    }
                    HStack {
                        StatStepper(title: "K (Swing)", value: $game.strikeoutsSwinging)
                        StatStepper(title: "K (Look)", value: $game.strikeoutsLooking)
                    }
                    HStack {
                        StatStepper(title: "SB", value: $game.stolenBases)
                        StatStepper(title: "CS", value: $game.caughtStealing)
                    }
                    HStack {
                        StatStepper(title: "WP", value: $game.wildPitches)
                        StatStepper(title: "PB", value: $game.passedBalls)
                    }
                    HStack {
                        StatStepper(title: "SF", value: $game.sacFlies)
                        StatStepper(title: "Sac Bunt", value: $game.sacBunts)
                    }
                    HStack {
                        StatStepper(title: "Balks", value: $game.balks)
                        Spacer()
                    }
                }
            }

            Section("Players (Box Score Lines)") {
                if game.playerLines.isEmpty {
                    Text("No players yet. Tap Add Player.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(game.playerLines.sorted(by: { $0.playerName < $1.playerName })) { pl in
                        NavigationLink {
                            PlayerLineView(game: game, player: pl)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayPlayerTitle(pl))
                                    .font(.headline)
                                Text("AB \(pl.atBats) • H \(pl.hits) • R \(pl.runs) • RBI \(pl.rbi) • BB \(pl.walks) • K \(pl.strikeoutsSwinging + pl.strikeoutsLooking)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if pl.pitched {
                                    Text("P: IP \(pl.inningsPitchedDisplay) • K \(pl.strikeoutsPitched) • BB \(pl.walksAllowed) • ER \(pl.earnedRunsAllowed) • ERA \(pl.eraDisplay)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deletePlayers)
                }
            }

            Section("Event Log (Review Notes)") {
                if game.events.isEmpty {
                    Text("No events logged yet. Add quick notes like errors, wild pitches, big plays, etc.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(game.events.sorted(by: { $0.createdAt > $1.createdAt })) { ev in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(ev.type.rawValue) • \(ev.inningDisplay)")
                                .font(.headline)
                            Text(ev.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteEvents)
                }
            }

            Section("Coach Notes") {
                TextEditor(text: $game.notes)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game Review" : "vs \(game.opponent)")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingQuickEvent = true
                } label: {
                    Label("Quick Event", systemImage: "bolt.fill")
                }

                Button {
                    showingAddPlayer = true
                } label: {
                    Label("Add Player", systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerSheet { player in
                player.game = game
                game.playerLines.append(player)
                modelContext.insert(player)
            }
        }
        .sheet(isPresented: $showingQuickEvent) {
            QuickEventSheet { ev in
                ev.game = game
                game.events.append(ev)

                // auto-bump team totals for certain events
                switch ev.type {
                case .error: game.errorsAgainst += 1
                case .wildPitch: game.wildPitches += 1
                case .passedBall: game.passedBalls += 1
                case .stolenBase: game.stolenBases += 1
                case .caughtStealing: game.caughtStealing += 1
                case .balk: game.balks += 1
                default: break
                }

                modelContext.insert(ev)
            }
        }
    }

    private func displayPlayerTitle(_ pl: PlayerLine) -> String {
        let num = pl.jerseyNumber.isEmpty ? "" : "#\(pl.jerseyNumber) "
        let pos = pl.primaryPosition.isEmpty ? "" : " • \(pl.primaryPosition)"
        return "\(num)\(pl.playerName)\(pos)"
    }

    private func deletePlayers(at offsets: IndexSet) {
        let sorted = game.playerLines.sorted(by: { $0.playerName < $1.playerName })
        for index in offsets {
            let p = sorted[index]
            modelContext.delete(p)
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        let sorted = game.events.sorted(by: { $0.createdAt > $1.createdAt })
        for index in offsets {
            let e = sorted[index]
            modelContext.delete(e)
        }
    }
}

// MARK: - Add Player

struct AddPlayerSheet: View {
    var onAdd: (PlayerLine) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    TextField("Name", text: $name)
                    TextField("Jersey #", text: $number)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Primary Position (e.g. SS, C, P)", text: $position)
                }

                Section {
                    Button {
                        let p = PlayerLine(playerName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                           jerseyNumber: number.trimmingCharacters(in: .whitespacesAndNewlines),
                                           primaryPosition: position.trimmingCharacters(in: .whitespacesAndNewlines))
                        onAdd(p)
                        dismiss()
                    } label: {
                        Text("Add Player")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add Player")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Player Line View (edit everything)

struct PlayerLineView: View {
    @Bindable var game: SavedGame
    @Bindable var player: PlayerLine

    var body: some View {
        List {
            Section("Batting") {
                StatStepper(title: "PA", value: $player.plateAppearances)
                StatStepper(title: "AB", value: $player.atBats)
                StatStepper(title: "R", value: $player.runs)
                StatStepper(title: "H", value: $player.hits)
                StatStepper(title: "2B", value: $player.doubles)
                StatStepper(title: "3B", value: $player.triples)
                StatStepper(title: "HR", value: $player.homeRuns)
                StatStepper(title: "RBI", value: $player.rbi)

                StatStepper(title: "BB", value: $player.walks, onChanged: syncTeamTotals)
                StatStepper(title: "HBP", value: $player.hitByPitch, onChanged: syncTeamTotals)
                StatStepper(title: "K (Swing)", value: $player.strikeoutsSwinging, onChanged: syncTeamTotals)
                StatStepper(title: "K (Look)", value: $player.strikeoutsLooking, onChanged: syncTeamTotals)

                StatStepper(title: "SF", value: $player.sacFlies, onChanged: syncTeamTotals)
                StatStepper(title: "Sac Bunt", value: $player.sacBunts, onChanged: syncTeamTotals)

                StatStepper(title: "SB", value: $player.stolenBases, onChanged: syncTeamTotals)
                StatStepper(title: "CS", value: $player.caughtStealing, onChanged: syncTeamTotals)
            }

            Section("Fielding") {
                StatStepper(title: "PO", value: $player.putouts)
                StatStepper(title: "A", value: $player.assists)
                StatStepper(title: "E", value: $player.errors, onChanged: syncErrorsFor)
                StatStepper(title: "PB (Catcher)", value: $player.passedBalls, onChanged: syncPassedBalls)
                StatStepper(title: "Pickoffs", value: $player.pitcherPickoffs)
            }

            Section("Pitching") {
                Toggle("Appeared as Pitcher", isOn: $player.pitched)
                if player.pitched {
                    OutsStepper(title: "Outs Recorded", outs: $player.outsRecorded)
                    StatStepper(title: "H Allowed", value: $player.hitsAllowed)
                    StatStepper(title: "R Allowed", value: $player.runsAllowed)
                    StatStepper(title: "ER", value: $player.earnedRunsAllowed)
                    StatStepper(title: "BB Allowed", value: $player.walksAllowed)
                    StatStepper(title: "K", value: $player.strikeoutsPitched)
                    StatStepper(title: "HBP", value: $player.hitBatters)
                    StatStepper(title: "WP", value: $player.wildPitches, onChanged: syncWildPitches)
                    StatStepper(title: "Balks", value: $player.balks, onChanged: syncBalks)

                    LabeledContent("IP") { Text(player.inningsPitchedDisplay) }
                    LabeledContent("ERA") { Text(player.eraDisplay) }
                }
            }

            Section("Slash Line (Review)") {
                LabeledContent("AVG") { Text(player.battingAverage) }
                LabeledContent("OBP") { Text(player.onBasePercentage) }
                LabeledContent("SLG") { Text(player.slugging) }
            }
        }
        .navigationTitle(player.playerName)
        .onAppear {
            // Make sure totals don’t drift if you edited earlier versions
            recomputeTeamTotalsFromPlayers()
        }
        .onDisappear {
            recomputeTeamTotalsFromPlayers()
        }
    }

    private func syncTeamTotals() {
        recomputeTeamTotalsFromPlayers()
    }

    private func syncErrorsFor() {
        // Sum player errors as "errorsFor" (your team)
        game.errorsFor = game.playerLines.reduce(0) { $0 + $1.errors }
    }

    private func syncPassedBalls() {
        game.passedBalls = game.playerLines.reduce(0) { $0 + $1.passedBalls }
    }

    private func syncWildPitches() {
        // Pitcher wild pitches -> team wild pitches
        let wp = game.playerLines.reduce(0) { $0 + $1.wildPitches }
        game.wildPitches = wp
    }

    private func syncBalks() {
        let b = game.playerLines.reduce(0) { $0 + $1.balks }
        game.balks = b
    }

    private func recomputeTeamTotalsFromPlayers() {
        let lines = game.playerLines

        game.walks = lines.reduce(0) { $0 + $1.walks }
        game.hitByPitch = lines.reduce(0) { $0 + $1.hitByPitch }
        game.strikeoutsSwinging = lines.reduce(0) { $0 + $1.strikeoutsSwinging }
        game.strikeoutsLooking = lines.reduce(0) { $0 + $1.strikeoutsLooking }
        game.sacFlies = lines.reduce(0) { $0 + $1.sacFlies }
        game.sacBunts = lines.reduce(0) { $0 + $1.sacBunts }
        game.stolenBases = lines.reduce(0) { $0 + $1.stolenBases }
        game.caughtStealing = lines.reduce(0) { $0 + $1.caughtStealing }

        game.errorsFor = lines.reduce(0) { $0 + $1.errors }
        game.passedBalls = lines.reduce(0) { $0 + $1.passedBalls }

        // Optional: Hits For can be summed from player hits if you want the game value auto
        game.hitsFor = lines.reduce(0) { $0 + $1.hits }
    }
}

// MARK: - Quick Event Sheet

struct QuickEventSheet: View {
    var onAdd: (GameEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: EventType = .note
    @State private var inning: Int = 1
    @State private var isTop: Bool = true
    @State private var detail: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Type", selection: $type) {
                        ForEach(EventType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }

                    Stepper("Inning: \(inning)", value: $inning, in: 1...20)
                    Toggle("Top of inning", isOn: $isTop)

                    TextField("Details (what happened?)", text: $detail, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Button {
                        let ev = GameEvent(type: type, inning: inning, isTop: isTop, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
                        onAdd(ev)
                        dismiss()
                    } label: {
                        Text("Add Event")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Quick Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reusable Controls

struct StatStepper: View {
    var title: String
    @Binding var value: Int
    var onChanged: (() -> Void)? = nil

    var body: some View {
        Stepper {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } onIncrement: {
            value += 1
            onChanged?()
        } onDecrement: {
            value = max(0, value - 1)
            onChanged?()
        }
    }
}

struct OutsStepper: View {
    var title: String
    @Binding var outs: Int

    var body: some View {
        Stepper {
            HStack {
                Text(title)
                Spacer()
                Text("\(outs)  (\(outs/3).\(outs%3) IP)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } onIncrement: {
            outs += 1
        } onDecrement: {
            outs = max(0, outs - 1)
        }
    }
}
