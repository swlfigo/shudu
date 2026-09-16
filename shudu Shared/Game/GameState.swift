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
            overlay: .newGame(allowsCancel: false)
        )
    }

    mutating func dispatch(_ action: GameAction) {
        switch action {
        case .selectCell(let index):
            selectCell(index)
        case .tapDigit(let digit):
            tapDigit(digit)
        case .clear:
            clear()
        case .toggleNotes:
            isNotesMode.toggle()
        case .applyGenerated(let puzzle, generationID: _):
            applyGenerated(puzzle)
        case .hint, .undo, .redo, .newGame, .chooseDifficulty, .cancelOverlay,
             .tick, .generationFailed, .appDidEnterBackground, .appDidBecomeActive:
            break
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
            return
        }

        placeDigit(digit, at: index)
    }

    private mutating func placeDigit(_ digit: Int, at index: Int) {
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

        let conflictDelta = conflictIndices.contains(index) ? 1 : 0
        conflictCount += conflictDelta
        pushUndo(UndoRecord(mutations: mutations, hintDelta: 0, conflictDelta: conflictDelta))
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
    }

    private mutating func applyGenerated(_ puzzle: Puzzle) {
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
        undoStack = []
        redoStack = []
        selectedIndex = nil
        isNotesMode = false
        isGenerating = false
        overlay = .none
    }

    private mutating func pushUndo(_ record: UndoRecord) {
        undoStack.append(record)
        redoStack.removeAll()
    }
}
