import Foundation

nonisolated struct Cell: Equatable, Sendable {
    var value: Int? = nil
    var isGiven: Bool = false
    var notes: Set<Int> = []
}

nonisolated enum Overlay: Equatable, Sendable {
    case none
    case newGame(allowsCancel: Bool)
    case win
    case settings
}

nonisolated enum GameAction: Equatable, Sendable {
    case selectCell(Int)
    case tapDigit(Int)
    case clear
    case toggleNotes
    case hint
    case undo
    case redo
    case newGame
    case openSettings
    case closeSettings
    case chooseDifficulty(Difficulty)
    case cancelOverlay
    case tick(TimeInterval)
    case applyGenerated(Puzzle, generationID: UInt)
    case generationFailed(generationID: UInt)
    case appDidEnterBackground
    case appDidBecomeActive
}
