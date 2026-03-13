import SwiftUI
import SwiftData
import Combine
import UIKit

// MARK: - SwiftData Model

import SwiftData
import Foundation

@Model
final class SavedGame {
    @Attribute(.unique) var id: UUID
    var savedAt: Date
    var title: String

    // ✅ SwiftData-friendly for Data blobs
    @Attribute(.externalStorage) var payload: Data

    init(id: UUID = UUID(), savedAt: Date = Date(), title: String, payload: Data) {
        self.id = id
        self.savedAt = savedAt
        self.title = title
        self.payload = payload
    }
}

// MARK: - Domain

enum TeamSide: String, CaseIterable, Identifiable, Codable {
    case home = "Home"
    case away = "Away"
    var id: String { rawValue }
}

enum HalfInning: String, CaseIterable, Identifiable, Codable {
    case top = "Top"
    case bottom = "Bottom"
    var id: String { rawValue }
}

struct InningStats: Codable, Hashable {
    // Runs only belong to the scoreboard (NOT included in mistakes)
    var runs: Int = 0

    // Defensive freebies/mistakes (charged to FIELDING team)
    var walksAllowed: Int = 0
    var hbpAllowed: Int = 0
    var errors: Int = 0
    var passedBall: Int = 0
    var wildPitch: Int = 0
    var balk: Int = 0
    var stolenBasesAgainst: Int = 0
    var otherFreeBase: Int = 0

    // Batting mistake (charged to BATTING team only)
    var strikeOutsBatting: Int = 0

    // Keep for convenience, but totals below will use explicit summing in ViewModel.
    var mistakesTotal: Int {
        walksAllowed
        + hbpAllowed
        + errors
        + passedBall
        + wildPitch
        + balk
        + stolenBasesAgainst
        + otherFreeBase
        + strikeOutsBatting
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

// In-memory state for gameplay/undo (not Codable)
struct GameState {
    var homeName = "HOME"
    var awayName = "AWAY"
    var inning: Int = 1
    var half: HalfInning = .top
    var outs: Int = 0

    var homeStats: [InningStats] = Array(repeating: InningStats(), count: 7)
    var awayStats: [InningStats] = Array(repeating: InningStats(), count: 7)
}

struct Snapshot { let game: GameState }

// MARK: - ViewModel

@MainActor
final class StatGameViewModel: ObservableObject {
    @Published var game = GameState()

    let maxInnings = 7
    private(set) var undoStack: [Snapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var inningIndex: Int { max(0, min(game.inning - 1, maxInnings - 1)) }

    // Top = Away batting, Bottom = Home batting
    var battingTeam: TeamSide { game.half == .top ? .away : .home }
    var fieldingTeam: TeamSide { game.half == .top ? .home : .away }

    private func pushUndo() {
        undoStack.append(Snapshot(game: game))
        if undoStack.count > 200 { undoStack.removeFirst() }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        game = last.game
    }

    // MARK: Totals

    func totals(for team: TeamSide) -> InningStats {
        let arr = (team == .home) ? game.homeStats : game.awayStats
        var t = InningStats()
        for s in arr {
            t.runs += s.runs
            t.walksAllowed += s.walksAllowed
            t.hbpAllowed += s.hbpAllowed
            t.errors += s.errors
            t.passedBall += s.passedBall
            t.wildPitch += s.wildPitch
            t.balk += s.balk
            t.stolenBasesAgainst += s.stolenBasesAgainst
            t.otherFreeBase += s.otherFreeBase
            t.strikeOutsBatting += s.strikeOutsBatting
        }
        return t
    }

    func runs(for team: TeamSide) -> Int { totals(for: team).runs }

    // ✅ FIX: Explicit sum so totals always match exactly what you track
    func mistakes(for team: TeamSide) -> Int {
        let t = totals(for: team)
        return t.walksAllowed
        + t.hbpAllowed
        + t.errors
        + t.passedBall
        + t.wildPitch
        + t.balk
        + t.stolenBasesAgainst
        + t.otherFreeBase
        + t.strikeOutsBatting
    }

    func errorsTotal(for team: TeamSide) -> Int { totals(for: team).errors }

    func leaderByMistakes() -> TeamSide? {
        let h = mistakes(for: .home)
        let a = mistakes(for: .away)
        if h == a { return nil }
        return h < a ? .home : .away
    }

    // MARK: Inning navigation

    func setHalf(_ half: HalfInning) {
        pushUndo()
        game.half = half
    }

    func setInning(_ inning: Int) {
        pushUndo()
        game.inning = max(1, min(maxInnings, inning))
    }

    func setOuts(_ outs: Int) {
        pushUndo()
        game.outs = max(0, min(2, outs))
    }

    func endHalfInning() {
        pushUndo()
        game.outs = 0
        if game.half == .top {
            game.half = .bottom
        } else {
            game.half = .top
            game.inning = min(game.inning + 1, maxInnings)
        }
    }

    func newGame() {
        pushUndo()
        game = GameState()
    }

    // MARK: Stat bump helpers

    private func bump(team: TeamSide, keyPath: WritableKeyPath<InningStats, Int>, delta: Int) {
        pushUndo()
        if team == .home {
            var s = game.homeStats[inningIndex]
            s[keyPath: keyPath] = max(0, s[keyPath: keyPath] + delta)
            game.homeStats[inningIndex] = s
        } else {
            var s = game.awayStats[inningIndex]
            s[keyPath: keyPath] = max(0, s[keyPath: keyPath] + delta)
            game.awayStats[inningIndex] = s
        }
    }

    // Runs -> batting team only (scoreboard only)
    func runPlus() { bump(team: battingTeam, keyPath: \.runs, delta: 1) }
    func runMinus() { bump(team: battingTeam, keyPath: \.runs, delta: -1) }

    // Defensive (fielding team)
    func walkAllowed() { bump(team: fieldingTeam, keyPath: \.walksAllowed, delta: 1) }
    func hbpAllowed() { bump(team: fieldingTeam, keyPath: \.hbpAllowed, delta: 1) }
    func error() { bump(team: fieldingTeam, keyPath: \.errors, delta: 1) }
    func passedBall() { bump(team: fieldingTeam, keyPath: \.passedBall, delta: 1) }
    func wildPitch() { bump(team: fieldingTeam, keyPath: \.wildPitch, delta: 1) }
    func balk() { bump(team: fieldingTeam, keyPath: \.balk, delta: 1) }
    func sbAgainst() { bump(team: fieldingTeam, keyPath: \.stolenBasesAgainst, delta: 1) }
    func otherFreeBase() { bump(team: fieldingTeam, keyPath: \.otherFreeBase, delta: 1) }

    // Batting mistake -> batting team only
    func strikeoutBatting() { bump(team: battingTeam, keyPath: \.strikeOutsBatting, delta: 1) }

    // Grid adjustments
    func adjust(team: TeamSide, inningIdx: Int, keyPath: WritableKeyPath<InningStats, Int>, delta: Int) {
        pushUndo()
        let idx = max(0, min(maxInnings - 1, inningIdx))
        if team == .home {
            var s = game.homeStats[idx]
            s[keyPath: keyPath] = max(0, s[keyPath: keyPath] + delta)
            game.homeStats[idx] = s
        } else {
            var s = game.awayStats[idx]
            s[keyPath: keyPath] = max(0, s[keyPath: keyPath] + delta)
            game.awayStats[idx] = s
        }
    }

    // MARK: Save/Load payload

    func makePayload() -> GameSavePayload {
        GameSavePayload(
            savedAt: Date(),
            homeName: game.homeName,
            awayName: game.awayName,
            inning: game.inning,
            half: game.half,
            outs: game.outs,
            homeStats: game.homeStats,
            awayStats: game.awayStats
        )
    }

    func load(payload: GameSavePayload) {
        pushUndo()
        game.homeName = payload.homeName
        game.awayName = payload.awayName
        game.inning = payload.inning
        game.half = payload.half
        game.outs = payload.outs
        game.homeStats = payload.homeStats
        game.awayStats = payload.awayStats
    }
}

// MARK: - Hold-to-repeat button (Undo)

struct HoldToRepeatButton: View {
    let title: String
    let systemImage: String
    let enabled: Bool
    let tap: () -> Void
    let repeatAction: () -> Void

    @State private var timer: Timer?
    @State private var pressing = false

    var body: some View {
        Button {
            guard enabled else { return }
            tap()
        } label: {
            Label(title, systemImage: systemImage)
        }
        .disabled(!enabled)
        .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 40, pressing: { isPressing in
            pressing = isPressing
            if isPressing { start() } else { stop() }
        }, perform: { })
        .onDisappear { stop() }
    }

    private func start() {
        guard enabled else { return }
        stop()
        repeatAction()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            if enabled && pressing { repeatAction() } else { stop() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF Export (includes full mistake category breakdown)

func makeStatsPDF(
    home: String,
    away: String,
    homeRuns: Int,
    awayRuns: Int,
    homeMistakes: Int,
    awayMistakes: Int,
    homeTotals: InningStats,
    awayTotals: InningStats
) throws -> URL {

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TGWTG_\(Int(Date().timeIntervalSince1970)).pdf")

    let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    let data = renderer.pdfData { ctx in
        ctx.beginPage()

        let title = "The Game Within The Game — Stat Report"
        let date = Date().formatted(date: .abbreviated, time: .shortened)

        func line(_ label: String, _ homeVal: Int, _ awayVal: Int) -> String {
            "\(label):   \(home) \(homeVal)    \(away) \(awayVal)"
        }

        let lines: [String] = [
            title,
            date,
            "",
            "Score (Runs Only):",
            "\(home): \(homeRuns)    \(away): \(awayRuns)",
            "",
            "Mistakes (Total):",
            "\(home): \(homeMistakes)    \(away): \(awayMistakes)",
            "",
            "Errors (Total):",
            "\(home): \(homeTotals.errors)    \(away): \(awayTotals.errors)",
            "",
            "Mistakes Breakdown (Totals):",
            line("BB Allowed", homeTotals.walksAllowed, awayTotals.walksAllowed),
            line("HBP Allowed", homeTotals.hbpAllowed, awayTotals.hbpAllowed),
            line("Errors", homeTotals.errors, awayTotals.errors),
            line("Passed Ball", homeTotals.passedBall, awayTotals.passedBall),
            line("Wild Pitch", homeTotals.wildPitch, awayTotals.wildPitch),
            line("Balk", homeTotals.balk, awayTotals.balk),
            line("SB Against", homeTotals.stolenBasesAgainst, awayTotals.stolenBasesAgainst),
            line("Other Free Base", homeTotals.otherFreeBase, awayTotals.otherFreeBase),
            line("Strike Outs (batting)", homeTotals.strikeOutsBatting, awayTotals.strikeOutsBatting),
            "",
            "Leader (fewest mistakes): " + (homeMistakes == awayMistakes ? "TIED" : (homeMistakes < awayMistakes ? home : away))
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .paragraphStyle: paragraphStyle
        ]

        var y: CGFloat = 40
        for line in lines {
            (line as NSString).draw(in: CGRect(x: 40, y: y, width: 532, height: 28), withAttributes: attrs)
            y += 22
        }
    }

    try data.write(to: url, options: .atomic)
    return url
}

// MARK: - UI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var vm = StatGameViewModel()

    @State private var showSetup = true
    @State private var showHistory = false

    @State private var shareURL: URL?
    @State private var showShare = false

    @State private var errorText: String?
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        headerCard
                        inningControls
                        mistakesGrid
                    }
                    .padding()
                }

                Divider()

                actionPad
                    .padding()
                    .background(.thinMaterial)
            }
            .navigationTitle("The Game Within The Game")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Setup") { showSetup = true }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    HoldToRepeatButton(
                        title: "Undo",
                        systemImage: "arrow.uturn.backward",
                        enabled: vm.canUndo,
                        tap: { vm.undo() },
                        repeatAction: { vm.undo() }
                    )

                    Button("PDF") { exportPDF() }
                    Button("History") { showHistory = true }
                    Button("Save") { saveGame() }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("New Game") { vm.newGame() }
                }
            }
            .sheet(isPresented: $showSetup) {
                SetupView(home: $vm.game.homeName, away: $vm.game.awayName)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(
                    onLoad: { loadGame($0) }
                )
            }
            .sheet(isPresented: $showShare) {
                if let shareURL { ShareSheet(items: [shareURL]) }
            }
            .alert("Saved!", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Game saved to History.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorText != nil },
                set: { _ in errorText = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "Unknown error")
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    // MARK: Header (Errors big, Score visible)
    private var headerCard: some View {
        let homeTotals = vm.totals(for: .home)
        let awayTotals = vm.totals(for: .away)

        let homeRuns = homeTotals.runs
        let awayRuns = awayTotals.runs

        let homeErrors = homeTotals.errors
        let awayErrors = awayTotals.errors

        let homeMistakes = vm.mistakes(for: .home)
        let awayMistakes = vm.mistakes(for: .away)

        let leaderText: String = {
            guard let leader = vm.leaderByMistakes() else { return "TIED" }
            return leader == .home ? "\(vm.game.homeName) LEADER" : "\(vm.game.awayName) LEADER"
        }()

        return VStack(spacing: 10) {

            // TOP ROW
            HStack {
                Text("LEADER")
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                Text(leaderText)
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())

                Spacer()

                // ✅ Top-right now shows ERRORS
                Text("Errors \(homeErrors)–\(awayErrors)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // BIG NUMBERS = MISTAKES
            HStack {

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.game.homeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(homeMistakes)")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()

                    Text("Mistakes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Errors: \(homeErrors)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Score: \(homeRuns)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(vm.game.awayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(awayMistakes)")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()

                    Text("Mistakes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Errors: \(awayErrors)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Score: \(awayRuns)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("\(vm.game.half.rawValue) \(vm.game.inning)")
                    .font(.headline)
                Spacer()
                Text("Outs: \(vm.game.outs)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Batting: \(vm.battingTeam == .home ? vm.game.homeName : vm.game.awayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Hold Undo to rewind")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Controls

    private var inningControls: some View {
        HStack(spacing: 10) {
            Stepper("Inning", value: Binding(
                get: { vm.game.inning },
                set: { vm.setInning($0) }
            ), in: 1...vm.maxInnings)
            .labelsHidden()

            Picker("Half", selection: Binding(
                get: { vm.game.half },
                set: { vm.setHalf($0) }
            )) {
                Text("Top").tag(HalfInning.top)
                Text("Bot").tag(HalfInning.bottom)
            }
            .pickerStyle(.segmented)

            Picker("Outs", selection: Binding(
                get: { vm.game.outs },
                set: { vm.setOuts($0) }
            )) {
                Text("0").tag(0)
                Text("1").tag(1)
                Text("2").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Button("End") { vm.endHalfInning() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: Mistakes Grid (per inning + totals)

    private var mistakesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mistakes (per inning) — tap +1, long-press −1")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    gridHeaderRow()
                    teamGrid(team: .home, name: vm.game.homeName, stats: vm.game.homeStats)
                    teamGrid(team: .away, name: vm.game.awayName, stats: vm.game.awayStats)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func gridHeaderRow() -> some View {
        HStack(spacing: 6) {
            Text(" ").frame(width: 200, alignment: .leading)
            ForEach(1...vm.maxInnings, id: \.self) { i in
                Text("\(i)")
                    .frame(width: 46)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Tot")
                .frame(width: 60, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func teamGrid(team: TeamSide, name: String, stats: [InningStats]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.subheadline.weight(.semibold))

            statRow(team: team, title: "Strike Outs (batting)", stats: stats, keyPath: \.strikeOutsBatting)
            statRow(team: team, title: "BB Allowed", stats: stats, keyPath: \.walksAllowed)
            statRow(team: team, title: "HBP Allowed", stats: stats, keyPath: \.hbpAllowed)
            statRow(team: team, title: "Errors", stats: stats, keyPath: \.errors)
            statRow(team: team, title: "Passed Ball", stats: stats, keyPath: \.passedBall)
            statRow(team: team, title: "Wild Pitch", stats: stats, keyPath: \.wildPitch)
            statRow(team: team, title: "Balk", stats: stats, keyPath: \.balk)
            statRow(team: team, title: "SB Against", stats: stats, keyPath: \.stolenBasesAgainst)
            statRow(team: team, title: "Other Free Base", stats: stats, keyPath: \.otherFreeBase)

            totalRow(team: team, stats: stats)
        }
    }

    private func statRow(team: TeamSide, title: String, stats: [InningStats], keyPath: WritableKeyPath<InningStats, Int>) -> some View {
        let total = stats.reduce(0) { $0 + $1[keyPath: keyPath] }

        return HStack(spacing: 6) {
            Text(title)
                .frame(width: 200, alignment: .leading)
                .font(.caption.weight(.semibold))

            ForEach(0..<vm.maxInnings, id: \.self) { idx in
                let value = stats[idx][keyPath: keyPath]
                StatCell(value: value) {
                    vm.adjust(team: team, inningIdx: idx, keyPath: keyPath, delta: 1)
                } onLongPress: {
                    vm.adjust(team: team, inningIdx: idx, keyPath: keyPath, delta: -1)
                }
            }

            Text("\(total)")
                .frame(width: 60, alignment: .leading)
                .font(.caption)
                .padding(6)
                .background(.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func totalRow(team: TeamSide, stats: [InningStats]) -> some View {
        // ✅ FIX: compute totals explicitly from the same fields used in vm.mistakes(for:)
        let total = stats.reduce(0) { acc, s in
            acc
            + s.walksAllowed
            + s.hbpAllowed
            + s.errors
            + s.passedBall
            + s.wildPitch
            + s.balk
            + s.stolenBasesAgainst
            + s.otherFreeBase
            + s.strikeOutsBatting
        }

        return HStack(spacing: 6) {
            Text("TOTAL (Mistakes)")
                .frame(width: 200, alignment: .leading)
                .font(.caption.weight(.bold))

            ForEach(0..<vm.maxInnings, id: \.self) { idx in
                let s = stats[idx]
                let value =
                    s.walksAllowed
                    + s.hbpAllowed
                    + s.errors
                    + s.passedBall
                    + s.wildPitch
                    + s.balk
                    + s.stolenBasesAgainst
                    + s.otherFreeBase
                    + s.strikeOutsBatting

                StatCell(value: value) { } onLongPress: { }
            }

            Text("\(total)")
                .frame(width: 60, alignment: .leading)
                .font(.caption.weight(.bold))
                .padding(6)
                .background(.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Buttons

    private var actionPad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                BigButton("Run +1", system: "plus.circle.fill") { vm.runPlus() }
                BigButton("Run -1", system: "minus.circle.fill") { vm.runMinus() }
            }
            HStack(spacing: 10) {
                BigButton("Strike Out (batting)", system: "k.circle.fill") { vm.strikeoutBatting() }
                BigButton("BB Allowed", system: "figure.walk") { vm.walkAllowed() }
            }
            HStack(spacing: 10) {
                BigButton("HBP Allowed", system: "bandage.fill") { vm.hbpAllowed() }
                BigButton("Error (E)", system: "exclamationmark.triangle.fill") { vm.error() }
            }
            HStack(spacing: 10) {
                BigButton("Passed Ball", system: "baseball.fill") { vm.passedBall() }
                BigButton("Wild Pitch", system: "wind") { vm.wildPitch() }
            }
            HStack(spacing: 10) {
                BigButton("Balk", system: "arrow.triangle.2.circlepath") { vm.balk() }
                BigButton("SB Against", system: "figure.run") { vm.sbAgainst() }
            }
            HStack(spacing: 10) {
                BigButton("Other Free Base", system: "flag.checkered") { vm.otherFreeBase() }
                BigButton("End Half", system: "arrow.right.circle.fill") { vm.endHalfInning() }
            }
        }
    }

    // MARK: Save/History/PDF

    private func saveGame() {
        do {
            let payload = vm.makePayload()
            let data = try JSONEncoder().encode(payload)
            let title = "\(payload.homeName) vs \(payload.awayName)"
            modelContext.insert(SavedGame(title: title, payload: data))
            try modelContext.save()
            showSavedAlert = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadGame(_ g: SavedGame) {
        do {
            let payload = try JSONDecoder().decode(GameSavePayload.self, from: g.payload)
            vm.load(payload: payload)
            showHistory = false
        } catch {
            errorText = "Load failed: \(error.localizedDescription)"
        }
    }

    private func deleteGame(_ g: SavedGame) {
        modelContext.delete(g)
        do { try modelContext.save() } catch { }
    }

    private func exportPDF() {
        do {
            let homeTotals = vm.totals(for: .home)
            let awayTotals = vm.totals(for: .away)

            let url = try makeStatsPDF(
                home: vm.game.homeName,
                away: vm.game.awayName,
                homeRuns: vm.runs(for: .home),
                awayRuns: vm.runs(for: .away),
                homeMistakes: vm.mistakes(for: .home),
                awayMistakes: vm.mistakes(for: .away),
                homeTotals: homeTotals,
                awayTotals: awayTotals
            )
            shareURL = url
            showShare = true
        } catch {
            errorText = "PDF failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Small Views

struct SetupView: View {
    @Binding var home: String
    @Binding var away: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    TextField("Home name", text: $home)
                    TextField("Away name", text: $away)
                }
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
            .navigationTitle("Setup")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedGame.savedAt, order: .reverse) private var games: [SavedGame]
    let onLoad: (SavedGame) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if games.isEmpty {
                    Text("No saved games yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(games) { g in
                        Button {
                            onLoad(g)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(g.title).font(.headline)
                                Text(g.savedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(g)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorText != nil },
                set: { _ in errorText = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "Unknown error")
            }
        }
    }

    private func delete(_ g: SavedGame) {
        modelContext.delete(g)
        do {
            try modelContext.save()
        } catch {
            errorText = "Delete failed: \(error.localizedDescription)"
        }
    }
}
struct BigButton: View {
    let title: String
    let system: String
    let action: () -> Void

    init(_ title: String, system: String, action: @escaping () -> Void) {
        self.title = title
        self.system = system
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: system).font(.system(size: 18, weight: .semibold))
                Text(title).font(.headline).lineLimit(2).minimumScaleFactor(0.85)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
    }
}

struct StatCell: View {
    let value: Int
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Text("\(value)")
            .font(.caption2)
            .frame(width: 46, height: 34)
            .background(.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { onTap() }
            .onLongPressGesture { onLongPress() }
    }
}

#Preview {
    ContentView()
}
