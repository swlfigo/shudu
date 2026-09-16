import XCTest
@testable import SudokuCore

final class SudokuSolverTests: XCTestCase {
    func testCountSolutions_completeIsOne() {
        let values: [Int?] = Fixtures.complete.map { $0 }
        XCTAssertEqual(SudokuSolver.countSolutions(values: values, limit: 2), 1)
    }

    func testCountSolutions_uniquePuzzleIsOne() {
        let g = Fixtures.givens([
            "53..7....",
            "6..195...",
            ".98....6.",
            "8...6...3",
            "4..8.3..1",
            "7...2...6",
            ".6....28.",
            "...419..5",
            "....8..79"
        ])
        XCTAssertEqual(SudokuSolver.countSolutions(values: g, limit: 2), 1)
        XCTAssertEqual(SudokuSolver.solvedValues(from: g), Fixtures.complete)
    }

    func testCountSolutions_ambiguousIsTwo() {
        var g: [Int?] = Fixtures.complete.map { $0 }
        g[0] = nil
        g[1] = nil
        // 两个给定被挖掉后该盘仍可能唯一；强制造多解：清空一整行
        g = Array(repeating: nil, count: 81)
        g[0] = 1
        XCTAssertEqual(SudokuSolver.countSolutions(values: g, limit: 2), 2)
    }

    func testFillComplete_isValidAndRandomizable() {
        var rng1 = SplitMix64(seed: 1)
        var rng2 = SplitMix64(seed: 2)
        let a = SudokuSolver.fillComplete(rng: &rng1)!
        let b = SudokuSolver.fillComplete(rng: &rng2)!
        XCTAssertTrue(SudokuBoard.isValidComplete(a))
        XCTAssertTrue(SudokuBoard.isValidComplete(b))
        XCTAssertNotEqual(a, b)
    }
}
