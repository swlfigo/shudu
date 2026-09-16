import XCTest
@testable import SudokuCore

final class SudokuRatingTests: XCTestCase {
    func testRate_singleHole_isEasy() {
        var g: [Int?] = Fixtures.complete.map { $0 }
        g[80] = nil
        XCTAssertEqual(SudokuSolver.rate(givens: g), .easy)
    }

    func testRate_empty_isHard() {
        let g: [Int?] = Array(repeating: nil, count: 81)
        XCTAssertEqual(SudokuSolver.rate(givens: g), .hard)
    }

    func testRate_hard17_thenFillUntilMedium() {
        // Brief's 17-clue is unique but singles-solvable. Frozen Inkala 2012 instead:
        // unique, rate==hard, and filling empties in index order hits medium.
        let hard = Fixtures.givens([
            "8........",
            "..36.....",
            ".7..9.2..",
            ".5...7...",
            "....457..",
            "...1...3.",
            "..1....68",
            "..85...1.",
            ".9....4.."
        ])
        XCTAssertEqual(SudokuSolver.countSolutions(values: hard, limit: 2), 1)
        XCTAssertEqual(SudokuSolver.rate(givens: hard), .hard)
        let sol = SudokuSolver.solvedValues(from: hard)!
        var g = hard
        var sawMedium = false
        for i in 0..<81 where g[i] == nil {
            g[i] = sol[i]
            if SudokuSolver.rate(givens: g) == .medium {
                sawMedium = true
                break
            }
        }
        XCTAssertTrue(sawMedium)
    }

    func testFindHintIndex_nakedSingle() {
        var v: [Int?] = Fixtures.complete.map { $0 }
        v[80] = nil
        XCTAssertEqual(SudokuSolver.findHintIndex(values: v), 80)
    }

    func testFindHintIndex_noEmpty() {
        let v: [Int?] = Fixtures.complete.map { $0 }
        XCTAssertNil(SudokuSolver.findHintIndex(values: v))
    }
}
