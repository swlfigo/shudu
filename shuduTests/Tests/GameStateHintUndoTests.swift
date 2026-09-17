import XCTest
@testable import SudokuCore

final class GameStateHintUndoTests: XCTestCase {
    func makeState() -> GameState {
        var s = GameState.newSession()
        let puzzle = Puzzle(
            givens: Fixtures.givens([
                "53..7....",
                "6..195...",
                ".98....6.",
                "8...6...3",
                "4..8.3..1",
                "7...2...6",
                ".6....28.",
                "...419..5",
                "....8..79"
            ]),
            solution: Fixtures.complete,
            difficulty: .easy
        )
        s.dispatch(.applyGenerated(puzzle, generationID: s.generationID))
        return s
    }

    func testHint_fillsSolutionAndDecrements() {
        var s = makeState()
        XCTAssertEqual(s.hintsRemaining, 3)
        s.dispatch(.hint)
        let idx = s.cells.indices.first { !s.cells[$0].isGiven && s.cells[$0].value != nil }!
        XCTAssertEqual(s.cells[idx].value, s.puzzle!.solution[idx])
        XCTAssertEqual(s.hintsRemaining, 2)
        XCTAssertEqual(s.conflictCount, 0)
    }

    func testHint_undoRestoresHintCount() {
        var s = makeState()
        s.dispatch(.hint)
        s.dispatch(.undo)
        XCTAssertEqual(s.hintsRemaining, 3)
        XCTAssertTrue(s.cells.allSatisfy { $0.isGiven || $0.value == nil })
        s.dispatch(.redo)
        XCTAssertEqual(s.hintsRemaining, 2)
    }

    func testUndoRedo_restoresNotes() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.toggleNotes)
        s.dispatch(.tapDigit(4))
        s.dispatch(.undo)
        XCTAssertTrue(s.cells[2].notes.isEmpty)
        s.dispatch(.redo)
        XCTAssertEqual(s.cells[2].notes, [4])
    }

    func testUndoRedo_doesNotChangeConflictCount() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(5)) // row0 already has given 5
        XCTAssertEqual(s.conflictCount, 1)
        s.dispatch(.undo)
        XCTAssertEqual(s.conflictCount, 1)
        XCTAssertNil(s.cells[2].value)
        s.dispatch(.redo)
        XCTAssertEqual(s.conflictCount, 1)
    }

    func testWin_whenFilledWithoutConflicts() {
        var s = makeState()
        for i in 0..<81 where !s.cells[i].isGiven {
            s.dispatch(.selectCell(i))
            s.dispatch(.tapDigit(s.puzzle!.solution[i]))
        }
        XCTAssertEqual(s.overlay, .win)
        XCTAssertFalse(s.timerRunning)
    }

    func testNoWin_whenConflictsRemain() {
        var s = makeState()
        for i in 0..<81 where !s.cells[i].isGiven {
            s.dispatch(.selectCell(i))
            s.dispatch(.tapDigit(s.puzzle!.solution[i]))
        }
        // 打开新状态再填一个冲突盘：最后一个空格填错
        s = makeState()
        let empties = s.cells.indices.filter { s.cells[$0].value == nil }
        for i in empties.dropLast() {
            s.dispatch(.selectCell(i))
            s.dispatch(.tapDigit(s.puzzle!.solution[i]))
        }
        let last = empties.last!
        let wrong = (1...9).first { $0 != s.puzzle!.solution[last] }!
        s.dispatch(.selectCell(last))
        s.dispatch(.tapDigit(wrong))
        XCTAssertNotEqual(s.overlay, .win)
    }

    func testHint_ignoredWhenNoneLeft() {
        var s = makeState()
        s.dispatch(.hint); s.dispatch(.hint); s.dispatch(.hint)
        let after = s
        s.dispatch(.hint)
        XCTAssertEqual(s.hintsRemaining, 0)
        XCTAssertEqual(s.cells.map(\.value), after.cells.map(\.value))
    }
}
