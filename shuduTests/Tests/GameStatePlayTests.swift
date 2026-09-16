import XCTest
@testable import SudokuCore

final class GameStatePlayTests: XCTestCase {
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

    func testGivensLocked() {
        var s = makeState()
        s.dispatch(.selectCell(0)) // given 5
        s.dispatch(.tapDigit(9))
        XCTAssertEqual(s.cells[0].value, 5)
        XCTAssertTrue(s.cells[0].isGiven)
    }

    func testPlaceDigit_clearsPeerNotes() {
        var s = makeState()
        XCTAssertTrue(SudokuBoard.peers(of: 2).contains(11))
        s.dispatch(.selectCell(2))
        s.dispatch(.toggleNotes)
        s.dispatch(.tapDigit(4))
        XCTAssertEqual(s.cells[2].notes, [4])
        s.dispatch(.toggleNotes)
        s.dispatch(.selectCell(11)) // same box/col-ish — use a peer of index 2
        s.dispatch(.tapDigit(4))
        XCTAssertFalse(s.cells[2].notes.contains(4))
    }

    func testConflictCount_incrementsOnConflictingPlace() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(5)) // row0 already has given 5
        XCTAssertTrue(s.conflictIndices.contains(2))
        XCTAssertTrue(s.conflictIndices.contains(0))
        XCTAssertEqual(s.conflictCount, 1)
        s.dispatch(.tapDigit(4)) // 正确解是 4，且不冲突
        XCTAssertEqual(s.conflictCount, 1) // 不回退
        XCTAssertTrue(s.conflictIndices.isEmpty)
    }

    func testClearIgnoresGiven() {
        var s = makeState()
        s.dispatch(.selectCell(0))
        s.dispatch(.clear)
        XCTAssertEqual(s.cells[0].value, 5)
    }

    func testTapDigitWithoutSelectionDoesNothing() {
        var s = makeState()
        let before = s
        s.dispatch(.tapDigit(1))
        s.dispatch(.clear)
        XCTAssertEqual(s.cells, before.cells)
    }
}
