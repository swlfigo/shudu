import XCTest
@testable import SudokuCore

final class SudokuBoardTests: XCTestCase {
    func testHintCounts() {
        XCTAssertEqual(Difficulty.easy.hintCount, 3)
        XCTAssertEqual(Difficulty.medium.hintCount, 2)
        XCTAssertEqual(Difficulty.hard.hintCount, 1)
    }

    func testDisplayNames() {
        XCTAssertEqual(Difficulty.easy.displayName, "简单")
        XCTAssertEqual(Difficulty.medium.displayName, "中等")
        XCTAssertEqual(Difficulty.hard.displayName, "困难")
    }

    func testIndexMapping() {
        XCTAssertEqual(SudokuBoard.row(10), 1)
        XCTAssertEqual(SudokuBoard.col(10), 1)
        XCTAssertEqual(SudokuBoard.box(10), 0)
        XCTAssertEqual(SudokuBoard.box(8), 2)
        XCTAssertEqual(SudokuBoard.box(80), 8)
    }

    func testPeersCountIs20() {
        XCTAssertEqual(SudokuBoard.peers(of: 0).count, 20)
        XCTAssertEqual(Set(SudokuBoard.peers(of: 40)).count, 20)
    }

    func testValidCompleteGrid() {
        let grid = Fixtures.complete
        XCTAssertEqual(grid.count, 81)
        XCTAssertTrue(SudokuBoard.isValidComplete(grid))
    }

    func testInvalidCompleteGridDuplicateInRow() {
        var grid = Fixtures.complete
        grid[1] = grid[0]
        XCTAssertFalse(SudokuBoard.isValidComplete(grid))
    }
}

enum Fixtures {
    /// 合法完整盘，后续任务复用。
    static let complete: [Int] = [
        5,3,4,6,7,8,9,1,2,
        6,7,2,1,9,5,3,4,8,
        1,9,8,3,4,2,5,6,7,
        8,5,9,7,6,1,4,2,3,
        4,2,6,8,5,3,7,9,1,
        7,1,3,9,2,4,8,5,6,
        9,6,1,5,3,7,2,8,4,
        2,8,7,4,1,9,6,3,5,
        3,4,5,2,8,6,1,7,9
    ]

    static func givens(_ rows: [String]) -> [Int?] {
        rows.joined().map { ch in
            ch == "." ? nil : Int(String(ch))
        }
    }
}
