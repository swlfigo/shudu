import XCTest
@testable import SudokuCore

final class SudokuGeneratorTests: XCTestCase {
    func testGenerate_returnsUniqueValidPuzzle() {
        var rng = SplitMix64(seed: 42)
        let deadline = Date().addingTimeInterval(8)
        let puzzle = SudokuGenerator.generate(difficulty: .easy, deadline: deadline, rng: &rng)
        XCTAssertNotNil(puzzle)
        let p = puzzle!
        XCTAssertEqual(p.difficulty, .easy)
        XCTAssertTrue(SudokuBoard.isValidComplete(p.solution))
        XCTAssertEqual(SudokuSolver.countSolutions(values: p.givens, limit: 2), 1)
        XCTAssertEqual(SudokuSolver.solvedValues(from: p.givens), p.solution)
        let givenCount = p.givens.compactMap { $0 }.count
        XCTAssertGreaterThanOrEqual(givenCount, 17)
        XCTAssertLessThan(givenCount, 81)
    }

    func testGenerate_timeoutStillReturnsIfPossible() {
        var rng = SplitMix64(seed: 7)
        let deadline = Date().addingTimeInterval(-1) // 已过期，走步骤 7
        let puzzle = SudokuGenerator.generate(difficulty: .hard, deadline: deadline, rng: &rng)
        // 允许 nil（极端），若非 nil 必须合法唯一
        if let p = puzzle {
            XCTAssertEqual(SudokuSolver.countSolutions(values: p.givens, limit: 2), 1)
            XCTAssertTrue(SudokuBoard.isValidComplete(p.solution))
        }
    }
}
