import Foundation

nonisolated struct Mutation: Equatable, Sendable {
    var index: Int
    var before: Cell
    var after: Cell
}

nonisolated struct UndoRecord: Equatable, Sendable {
    var mutations: [Mutation]
    var hintDelta: Int
    var conflictDelta: Int
}

nonisolated struct GameState: Equatable, Sendable {
    var puzzle: Puzzle?
    var cells: [Cell]
    var selectedIndex: Int?
    var isNotesMode: Bool
    var hintsRemaining: Int
    var conflictCount: Int
    var elapsed: TimeInterval
    var timerRunning: Bool
    var undoStack: [UndoRecord]
    var redoStack: [UndoRecord]
    var isGenerating: Bool
    var generationID: UInt
    var overlay: Overlay
    var pendingDifficulty: Difficulty?
    var generationFailed: Bool
    var isInBackground: Bool
    var timerStarted: Bool

    var conflictIndices: Set<Int> {
        var result = Set<Int>()
        for i in cells.indices {
            guard let value = cells[i].value else { continue }
            if SudokuBoard.peers(of: i).contains(where: { cells[$0].value == value }) {
                result.insert(i)
            }
        }
        return result
    }

    var isWon: Bool {
        cells.count == SudokuBoard.cellCount
            && cells.allSatisfy { $0.value != nil }
            && conflictIndices.isEmpty
    }

    var formattedElapsed: String {
        let t = Int(elapsed)
        if t >= 3600 {
            return String(format: "%d:%02d:%02d", t/3600, (t%3600)/60, t%60)
        }
        return String(format: "%d:%02d", t/60, t%60)
    }

    private var ignoresBoardInput: Bool {
        overlay != .none || isGenerating
    }

    static func newSession() -> GameState {
        GameState(
            puzzle: nil,
            cells: Array(repeating: Cell(), count: SudokuBoard.cellCount),
            selectedIndex: nil,
            isNotesMode: false,
            hintsRemaining: 0,
            conflictCount: 0,
            elapsed: 0,
            timerRunning: false,
            undoStack: [],
            redoStack: [],
            isGenerating: false,
            generationID: 1,
            overlay: .newGame(allowsCancel: false),
            pendingDifficulty: nil,
            generationFailed: false,
            isInBackground: false,
            timerStarted: false
        )
    }

    mutating func dispatch(_ action: GameAction) {
        switch action {
        case .selectCell(let index):
            guard !ignoresBoardInput else { return }
            selectCell(index)
        case .tapDigit(let digit):
            guard !ignoresBoardInput else { return }
            tapDigit(digit)
        case .clear:
            guard !ignoresBoardInput else { return }
            clear()
        case .toggleNotes:
            guard !ignoresBoardInput else { return }
            isNotesMode.toggle()
        case .applyGenerated(let puzzle, let generationID):
            applyGenerated(puzzle, generationID: generationID)
        case .hint:
            guard !ignoresBoardInput else { return }
            hint()
        case .undo:
            guard !ignoresBoardInput else { return }
            undo()
        case .redo:
            guard !ignoresBoardInput else { return }
            redo()
        case .newGame:
            beginNewGame()
        case .chooseDifficulty(let difficulty):
            chooseDifficulty(difficulty)
        case .cancelOverlay:
            cancelOverlay()
        case .tick(let delta):
            tick(delta)
        case .generationFailed(let generationID):
            failGeneration(generationID: generationID)
        case .appDidEnterBackground:
            enterBackground()
        case .appDidBecomeActive:
            becomeActive()
        }
    }

    private mutating func selectCell(_ index: Int) {
        guard cells.indices.contains(index) else { return }
        selectedIndex = index
    }

    private mutating func tapDigit(_ digit: Int) {
        guard (1...9).contains(digit) else { return }
        guard let index = selectedIndex else { return }
        guard cells.indices.contains(index), !cells[index].isGiven else { return }

        if isNotesMode {
            guard cells[index].value == nil else { return }
            var cell = cells[index]
            let before = cell
            if cell.notes.contains(digit) {
                cell.notes.remove(digit)
            } else {
                cell.notes.insert(digit)
            }
            cells[index] = cell
            pushUndo(UndoRecord(
                mutations: [Mutation(index: index, before: before, after: cell)],
                hintDelta: 0,
                conflictDelta: 0
            ))
            markBoardChanged()
            return
        }

        placeDigit(digit, at: index)
    }

    private mutating func placeDigit(_ digit: Int, at index: Int) {
        let mutations = writeDigit(digit, at: index)
        let conflictDelta = conflictIndices.contains(index) ? 1 : 0
        conflictCount += conflictDelta
        pushUndo(UndoRecord(mutations: mutations, hintDelta: 0, conflictDelta: conflictDelta))
        markBoardChanged()
        updateWin()
    }

    private mutating func writeDigit(_ digit: Int, at index: Int) -> [Mutation] {
        let before = cells[index]
        var mutations: [Mutation] = []
        cells[index].value = digit
        cells[index].notes = []
        mutations.append(Mutation(index: index, before: before, after: cells[index]))

        for peer in SudokuBoard.peers(of: index) {
            guard cells[peer].notes.contains(digit) else { continue }
            let peerBefore = cells[peer]
            cells[peer].notes.remove(digit)
            mutations.append(Mutation(index: peer, before: peerBefore, after: cells[peer]))
        }
        return mutations
    }

    private mutating func hint() {
        guard hintsRemaining > 0, let puzzle else { return }
        guard cells.contains(where: { $0.value == nil }) else { return }
        let values = cells.map(\.value)
        guard let index = SudokuSolver.findHintIndex(values: values) else { return }
        guard cells.indices.contains(index), !cells[index].isGiven else { return }
        guard puzzle.solution.indices.contains(index) else { return }
        let digit = puzzle.solution[index]
        let mutations = writeDigit(digit, at: index)
        hintsRemaining -= 1
        pushUndo(UndoRecord(mutations: mutations, hintDelta: -1, conflictDelta: 0))
        markBoardChanged()
        updateWin()
    }

    private mutating func undo() {
        guard let record = undoStack.popLast() else { return }
        apply(record.mutations, forward: false)
        hintsRemaining -= record.hintDelta
        redoStack.append(record)
        updateWin()
    }

    private mutating func redo() {
        guard let record = redoStack.popLast() else { return }
        apply(record.mutations, forward: true)
        hintsRemaining += record.hintDelta
        undoStack.append(record)
        updateWin()
    }

    private mutating func apply(_ mutations: [Mutation], forward: Bool) {
        let sequence = forward ? mutations : mutations.reversed()
        for mutation in sequence {
            guard cells.indices.contains(mutation.index) else { continue }
            cells[mutation.index] = forward ? mutation.after : mutation.before
        }
    }

    private mutating func updateWin() {
        if isWon {
            overlay = .win
            timerRunning = false
        }
    }

    private mutating func clear() {
        guard let index = selectedIndex else { return }
        guard cells.indices.contains(index), !cells[index].isGiven else { return }
        let before = cells[index]
        guard before.value != nil || !before.notes.isEmpty else { return }
        cells[index].value = nil
        cells[index].notes = []
        pushUndo(UndoRecord(
            mutations: [Mutation(index: index, before: before, after: cells[index])],
            hintDelta: 0,
            conflictDelta: 0
        ))
        markBoardChanged()
        updateWin()
    }

    private mutating func applyGenerated(_ puzzle: Puzzle, generationID: UInt) {
        guard generationID == self.generationID else { return }
        self.puzzle = puzzle
        cells = puzzle.givens.map { given in
            if let value = given {
                return Cell(value: value, isGiven: true)
            }
            return Cell()
        }
        hintsRemaining = puzzle.difficulty.hintCount
        conflictCount = 0
        elapsed = 0
        timerRunning = false
        timerStarted = false
        undoStack = []
        redoStack = []
        selectedIndex = nil
        isNotesMode = false
        isGenerating = false
        generationFailed = false
        overlay = .none
    }

    private mutating func beginNewGame() {
        generationFailed = false
        let allowsCancel = puzzle != nil && overlay != .win
        overlay = .newGame(allowsCancel: allowsCancel)
        pauseTimer()
    }

    private mutating func chooseDifficulty(_ difficulty: Difficulty) {
        generationID += 1
        isGenerating = true
        pendingDifficulty = difficulty
        generationFailed = false
        let allowsCancel: Bool
        if case .newGame(let current) = overlay {
            allowsCancel = current
        } else {
            allowsCancel = puzzle != nil && overlay != .win
        }
        overlay = .newGame(allowsCancel: allowsCancel)
        pauseTimer()
    }

    private mutating func cancelOverlay() {
        guard !isGenerating else { return }
        guard case .newGame(let allowsCancel) = overlay, allowsCancel else { return }
        generationFailed = false
        overlay = .none
        resumeTimerIfNeeded()
    }

    private mutating func failGeneration(generationID: UInt) {
        guard generationID == self.generationID else { return }
        isGenerating = false
        generationFailed = true
    }

    private mutating func tick(_ delta: TimeInterval) {
        guard timerRunning else { return }
        elapsed += delta
    }

    private mutating func enterBackground() {
        isInBackground = true
        pauseTimer()
    }

    private mutating func becomeActive() {
        isInBackground = false
        resumeTimerIfNeeded()
    }

    private mutating func markBoardChanged() {
        timerStarted = true
        resumeTimerIfNeeded()
    }

    private mutating func pauseTimer() {
        timerRunning = false
    }

    private mutating func resumeTimerIfNeeded() {
        guard overlay == .none, !isGenerating, !isInBackground, timerStarted, !isWon else { return }
        timerRunning = true
    }

    private mutating func pushUndo(_ record: UndoRecord) {
        undoStack.append(record)
        redoStack.removeAll()
    }
}
