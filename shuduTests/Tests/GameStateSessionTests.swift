import XCTest
@testable import SudokuCore

final class GameStateSessionTests: XCTestCase {
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

    func testNewSession_startsWithDifficultyPicker() {
        let s = GameState.newSession()
        XCTAssertEqual(s.overlay, .newGame(allowsCancel: false))
        XCTAssertNil(s.puzzle)
    }

    func testChooseDifficulty_incrementsGenerationAndFlagsGenerating() {
        var s = GameState.newSession()
        let id = s.generationID
        s.dispatch(.chooseDifficulty(.medium))
        XCTAssertTrue(s.isGenerating)
        XCTAssertEqual(s.generationID, id + 1)
        XCTAssertEqual(s.pendingDifficulty, .medium)
    }

    func testStaleApplyGenerated_isIgnored() {
        var s = GameState.newSession()
        s.dispatch(.chooseDifficulty(.easy))
        let stale = s.generationID
        s.dispatch(.chooseDifficulty(.hard))
        let puzzle = Puzzle(givens: Array(repeating: nil, count: 81), solution: Fixtures.complete, difficulty: .easy)
        s.dispatch(.applyGenerated(puzzle, generationID: stale))
        XCTAssertTrue(s.isGenerating)
        XCTAssertNil(s.puzzle)
    }

    func testTimerStartsOnFirstEditAndFormats() {
        var s = makeState()
        XCTAssertFalse(s.timerRunning)
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        XCTAssertTrue(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:05")
        s.dispatch(.tick(3600))
        XCTAssertEqual(s.formattedElapsed, "1:00:05")
    }

    func testOverlayBlocksBoardInput() {
        var s = makeState()
        s.dispatch(.newGame)
        XCTAssertEqual(s.overlay, .newGame(allowsCancel: true))
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        XCTAssertNil(s.cells[2].value)
        s.dispatch(.cancelOverlay)
        XCTAssertEqual(s.overlay, .none)
    }

    func testWinThenPlayAgain() {
        var s = makeState()
        s.overlay = .win
        s.dispatch(.newGame)
        XCTAssertEqual(s.overlay, .newGame(allowsCancel: false)) // 胜利后再来一局：无「取消」回已结束盘，allowsCancel false
    }

    func testGenerationFailed_matchingID_staysOnNewGame() {
        var s = GameState.newSession()
        s.dispatch(.chooseDifficulty(.easy))
        let id = s.generationID
        s.dispatch(.generationFailed(generationID: id))
        XCTAssertFalse(s.isGenerating)
        XCTAssertTrue(s.generationFailed)
        XCTAssertEqual(s.overlay, .newGame(allowsCancel: false))
        XCTAssertNil(s.puzzle)
    }

    func testGenerationFailed_staleID_isIgnored() {
        var s = GameState.newSession()
        s.dispatch(.chooseDifficulty(.easy))
        let stale = s.generationID
        s.dispatch(.chooseDifficulty(.hard))
        s.dispatch(.generationFailed(generationID: stale))
        XCTAssertTrue(s.isGenerating)
        XCTAssertFalse(s.generationFailed)
    }

    func testChooseDifficulty_clearsGenerationFailed() {
        var s = GameState.newSession()
        s.dispatch(.chooseDifficulty(.easy))
        s.dispatch(.generationFailed(generationID: s.generationID))
        XCTAssertTrue(s.generationFailed)
        s.dispatch(.chooseDifficulty(.medium))
        XCTAssertFalse(s.generationFailed)
        XCTAssertTrue(s.isGenerating)
        XCTAssertEqual(s.pendingDifficulty, .medium)
    }

    func testCancelOverlay_ignoredWhileGenerating() {
        var s = makeState()
        s.dispatch(.newGame)
        s.dispatch(.chooseDifficulty(.medium))
        s.dispatch(.cancelOverlay)
        XCTAssertTrue(s.isGenerating)
        XCTAssertEqual(s.overlay, .newGame(allowsCancel: true))
        XCTAssertNotNil(s.puzzle)
    }

    func testApplyGenerated_matchingID_startsGame() {
        var s = GameState.newSession()
        s.dispatch(.chooseDifficulty(.easy))
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
        XCTAssertFalse(s.isGenerating)
        XCTAssertFalse(s.generationFailed)
        XCTAssertNotNil(s.puzzle)
        XCTAssertEqual(s.overlay, .none)
        XCTAssertEqual(s.hintsRemaining, 3)
        XCTAssertFalse(s.timerRunning)
        XCTAssertEqual(s.formattedElapsed, "0:00")
    }

    func testTick_ignoredWhenTimerNotRunning() {
        var s = makeState()
        s.dispatch(.tick(10))
        XCTAssertEqual(s.formattedElapsed, "0:00")
        XCTAssertFalse(s.timerRunning)
    }

    func testOverlayPausesTimerAndCancelResumes() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        XCTAssertTrue(s.timerRunning)
        s.dispatch(.newGame)
        XCTAssertFalse(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:00")
        s.dispatch(.cancelOverlay)
        XCTAssertEqual(s.overlay, .none)
        XCTAssertTrue(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:05")
    }

    func testBackgroundPausesAndActiveResumes() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        s.dispatch(.appDidEnterBackground)
        XCTAssertFalse(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:00")
        s.dispatch(.appDidBecomeActive)
        XCTAssertTrue(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:05")
    }

    func testActiveDoesNotResumeWhileOverlayShowing() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        s.dispatch(.newGame)
        s.dispatch(.appDidEnterBackground)
        s.dispatch(.appDidBecomeActive)
        XCTAssertFalse(s.timerRunning)
        s.dispatch(.tick(5))
        XCTAssertEqual(s.formattedElapsed, "0:00")
    }

    func testOverlayBlocksHintUndoNotes() {
        var s = makeState()
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        XCTAssertEqual(s.cells[2].value, 4)
        s.dispatch(.newGame)
        let hints = s.hintsRemaining
        s.dispatch(.hint)
        XCTAssertEqual(s.hintsRemaining, hints)
        s.dispatch(.toggleNotes)
        XCTAssertFalse(s.isNotesMode)
        s.dispatch(.undo)
        XCTAssertEqual(s.cells[2].value, 4)
        s.dispatch(.redo)
        XCTAssertEqual(s.cells[2].value, 4)
        s.dispatch(.clear)
        XCTAssertEqual(s.cells[2].value, 4)
        s.dispatch(.cancelOverlay)
        s.dispatch(.undo)
        XCTAssertNil(s.cells[2].value)
    }

    func testGeneratingBlocksBoardInput() {
        var s = makeState()
        s.dispatch(.newGame)
        s.dispatch(.chooseDifficulty(.hard))
        s.dispatch(.selectCell(2))
        s.dispatch(.tapDigit(4))
        s.dispatch(.hint)
        XCTAssertNil(s.cells[2].value)
        XCTAssertEqual(s.hintsRemaining, 3)
    }
}
