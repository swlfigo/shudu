# Sudoku Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 SpriteKit iOS/macOS 工程里做出可玩的标准 9×9 休闲数独：随机唯一解、三档难度、有限次提示、笔记、撤销/重做、计时、冲突高亮。

**Architecture:** Engine（生成/求解/评级）和 Game（一局状态机）是纯 Swift、`nonisolated`、可 `swift test`。SpriteKit UI 只读 `GameState`、把点击变成 `GameAction`。iOS/macOS 共用 `GameScene`，按场景宽高在竖排/横排之间切换。

**Tech Stack:** Swift 5、SpriteKit、XCTest via SwiftPM（`shuduTests`）、Xcode 双 target（`shudu iOS` / `shudu macOS`）。无第三方库。

**Spec:** `docs/superpowers/specs/2026-09-16-sudoku-game-design.md`

## Global Constraints

- 标准 9×9，下标 `0...80`：`row = i/9`，`col = i%9`，`box = (row/3)*3 + col/3`
- 难度：easy/medium/hard，提示次数 **3 / 2 / 1**，中文名 **简单 / 中等 / 困难**
- 提示：填入 `puzzle.solution` 的一格；优先 Naked/Hidden Single，否则最小空格下标
- 冲突只看行列宫重复，不对照答案判错；满盘无冲突即胜
- 生成在后台，墙上时间 **8 秒**，最多 **20** 轮；超时用本轮唯一盘
- 给定下限：easy 36、medium 28、hard 22（只作挖空下限，难度以手法评级为准）
- 视觉色值按 spec 原文，不得改
- 棋盘最小边长 **288pt**；Mac `minSize` **480×640**
- App target 开启了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。所有 Engine 类型、`GameState`、`GameAction` 必须标 `nonisolated`，并 `Sendable`，否则后台生成无法编译
- Engine/Game **禁止** import SpriteKit / UIKit / AppKit
- 测试跑：`swift test --package-path shuduTests`（见 Task 1 的 Package.swift）
- 应用编译：`xcodebuild -project shudu.xcodeproj -scheme "shudu iOS" -destination 'generic/platform=iOS Simulator' build` 以及 `-scheme "shudu macOS" -destination 'platform=macOS' build`

## File Structure

- Create: `shuduTests/Package.swift` — 把 `../shudu Shared/Engine` 与 `../shudu Shared/Game` 编成 `SudokuCore`，测试 target 名 `SudokuCoreTests`，目录 `shuduTests/Tests`
- Create: `shudu Shared/Engine/Difficulty.swift`
- Create: `shudu Shared/Engine/SudokuBoard.swift`
- Create: `shudu Shared/Engine/SudokuSolver.swift`
- Create: `shudu Shared/Engine/SudokuGenerator.swift`
- Create: `shudu Shared/Game/GameCommand.swift` — `GameAction` / `Overlay` / `Cell`
- Create: `shudu Shared/Game/GameState.swift`
- Create: `shudu Shared/UI/Palette.swift`
- Create: `shudu Shared/UI/CellNode.swift`
- Create: `shudu Shared/UI/BoardNode.swift`
- Create: `shudu Shared/UI/NumberPadNode.swift`
- Create: `shudu Shared/UI/HUDNode.swift`
- Create: `shudu Shared/UI/NewGameOverlayNode.swift`
- Modify: `shudu Shared/GameScene.swift` — 删掉 Hello/spinny，改为对局 Scene
- Modify: `shudu iOS/GameViewController.swift`、`shudu macOS/GameViewController.swift` — 关 FPS，接 Scene，Mac 设 minSize
- Create: `.gitignore` — `.superpowers/`、`.build/`、`.swiftpm/`
- `shudu Shared` 通过 `PBXFileSystemSynchronizedBuildFileExceptionSet.membershipExceptions` 进 iOS/macOS target。**磁盘上新建的 Shared 文件不会自动进 app。** 每新增一个 `shudu Shared/**/*.swift`，必须把相对路径（如 `Engine/Difficulty.swift`）同时加进 `project.pbxproj` 里两处 `Exceptions for "shudu Shared"` 的 `membershipExceptions` 列表（iOS 那组 `2CA4F34F`、macOS 那组 `2CA4F354`）。`GameScene.sks` 可留着但不再加载。

---

### Task 1: 测试脚手架 + Difficulty + SudokuBoard

**Files:**
- Create: `shuduTests/Package.swift`
- Create: `.gitignore`
- Create: `shudu Shared/Engine/Difficulty.swift`
- Create: `shudu Shared/Engine/SudokuBoard.swift`
- Create: `shuduTests/Tests/SudokuBoardTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `nonisolated enum Difficulty: String, CaseIterable, Sendable` with `hintCount: Int`, `displayName: String`
  - `nonisolated enum SudokuBoard` with `size`, `cellCount`, `row/col/box(_:)`, `unit(of:) -> [Int]`, `peers(of:) -> [Int]`, `isValidComplete(_ values: [Int]) -> Bool`

- [ ] **Step 1: 写 Package.swift 和 .gitignore**

`shuduTests/Package.swift`：

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"])
    ],
    targets: [
        .target(
            name: "SudokuCore",
            path: "../shudu Shared",
            sources: ["Engine", "Game"]
        ),
        .testTarget(
            name: "SudokuCoreTests",
            dependencies: ["SudokuCore"],
            path: "Tests"
        )
    ]
)
```

`.gitignore` 追加（文件不存在就新建）：

```
.superpowers/
.build/
.swiftpm/
xcuserdata/
.DS_Store
```

- [ ] **Step 2: 写失败测试**

`shuduTests/Tests/SudokuBoardTests.swift`：

```swift
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
```

- [ ] **Step 3: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter SudokuBoardTests`
Expected: FAIL，`SudokuCore` 模块不存在或 `Difficulty` 找不到

- [ ] **Step 4: 最小实现**

`shudu Shared/Engine/Difficulty.swift`：

```swift
nonisolated enum Difficulty: String, CaseIterable, Sendable {
    case easy, medium, hard

    var hintCount: Int {
        switch self {
        case .easy: 3
        case .medium: 2
        case .hard: 1
        }
    }

    var displayName: String {
        switch self {
        case .easy: "简单"
        case .medium: "中等"
        case .hard: "困难"
        }
    }

    var givenFloor: Int {
        switch self {
        case .easy: 36
        case .medium: 28
        case .hard: 22
        }
    }
}
```

`shudu Shared/Engine/SudokuBoard.swift`：

```swift
nonisolated enum SudokuBoard: Sendable {
    static let size = 9
    static let cellCount = 81

    static func row(_ i: Int) -> Int { i / 9 }
    static func col(_ i: Int) -> Int { i % 9 }
    static func box(_ i: Int) -> Int { (row(i) / 3) * 3 + col(i) / 3 }

    static func unit(of index: Int) -> [Int] {
        let r = row(index), c = col(index), b = box(index)
        var set = Set<Int>()
        for k in 0..<9 {
            set.insert(r * 9 + k)
            set.insert(k * 9 + c)
            let br = (b / 3) * 3, bc = (b % 3) * 3
            set.insert((br + k / 3) * 9 + (bc + k % 3))
        }
        return Array(set)
    }

    static func peers(of index: Int) -> [Int] {
        unit(of: index).filter { $0 != index }
    }

    static func isValidComplete(_ values: [Int]) -> Bool {
        guard values.count == 81, values.allSatisfy({ (1...9).contains($0) }) else { return false }
        func unique(_ idxs: [Int]) -> Bool {
            Set(idxs.map { values[$0] }).count == 9
        }
        for i in 0..<9 {
            let row = (0..<9).map { i * 9 + $0 }
            let col = (0..<9).map { $0 * 9 + i }
            let br = (i / 3) * 3, bc = (i % 3) * 3
            let box = (0..<9).map { (br + $0 / 3) * 9 + (bc + $0 % 3) }
            if !unique(row) || !unique(col) || !unique(box) { return false }
        }
        return true
    }
}
```

在 `shudu Shared/Game/` 放占位，否则 SPM `sources: ["Engine", "Game"]` 在 Game 目录不存在时失败：

`shudu Shared/Game/GameCommand.swift`：

```swift
nonisolated struct Cell: Equatable, Sendable {
    var value: Int?
    var isGiven: Bool
    var notes: Set<Int>
}
```

把 `Engine/Difficulty.swift`、`Engine/SudokuBoard.swift`、`Game/GameCommand.swift` 写入 `project.pbxproj` 两处 Shared `membershipExceptions`（见 Global Constraints）。

- [ ] **Step 5: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter SudokuBoardTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add shuduTests/Package.swift shuduTests/Tests .gitignore "shudu Shared/Engine" "shudu Shared/Game" shudu.xcodeproj/project.pbxproj
git commit -m "feat: add sudoku board helpers, difficulty, and test package"
```

---

### Task 2: 求解器（填满 + 数解）

**Files:**
- Create: `shudu Shared/Engine/SudokuSolver.swift`
- Create: `shuduTests/Tests/SudokuSolverTests.swift`

**Interfaces:**
- Consumes: `SudokuBoard`, `Fixtures.complete`
- Produces:
  - `SudokuSolver.countSolutions(values: [Int?], limit: Int) -> Int`
  - `SudokuSolver.fillComplete(rng: inout some RandomNumberGenerator) -> [Int]?`
  - `SudokuSolver.solvedValues(from givens: [Int?]) -> [Int]?`（limit 1 的解，没有则 nil）

- [ ] **Step 1: 写失败测试**

`shuduTests/Tests/SudokuSolverTests.swift`：

```swift
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

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
```

把 `SplitMix64` 放到 `shuduTests/Tests/SplitMix64.swift`（测试 target 会自动编译），`SudokuSolverTests` 与 `SudokuGeneratorTests` 共用。

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter SudokuSolverTests`
Expected: FAIL，`SudokuSolver` 不存在

- [ ] **Step 3: 实现位掩码回溯**

`shudu Shared/Engine/SudokuSolver.swift`：用泛型 `search`，不要做类型擦除 RNG。

`countSolutions` / `solvedValues` 预填掩码后调用 `search` 且 `randomize: false`。`fillComplete` 空盘、`randomize: true`，把 `&rng` 传进去。冲突预填（同一单元重复数字）直接返回 0。

`search` 做成泛型：

```swift
private static func search<R: RandomNumberGenerator>(
    _ board: inout [Int?],
    _ rows: inout [UInt16],
    _ cols: inout [UInt16],
    _ boxes: inout [UInt16],
    _ found: inout Int,
    _ limit: Int,
    randomize: Bool,
    rng: UnsafeMutablePointer<R>?
) -> Bool {
    if found >= limit { return true }
    guard let i = pickEmpty(board, rows, cols, boxes) else {
        found += 1
        return found >= limit
    }
    let r = i / 9, c = i % 9, b = (r / 3) * 3 + c / 3
    let used = rows[r] | cols[c] | boxes[b]
    var digits = [Int]()
    for d in 1...9 where used & (1 << d) == 0 { digits.append(d) }
    if randomize, let rng else {
        digits.shuffle(using: &rng.pointee)
    }
    for d in digits {
        let bit = UInt16(1) << d
        board[i] = d
        rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
        if search(&board, &rows, &cols, &boxes, &found, limit, randomize: randomize, rng: rng) && found >= limit {
            return true
        }
        board[i] = nil
        rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit
    }
    return false
}

private static func pickEmpty(_ board: [Int?], _ rows: [UInt16], _ cols: [UInt16], _ boxes: [UInt16]) -> Int? {
    var best: Int?
    var bestCount = 10
    for i in 0..<81 where board[i] == nil {
        let r = i / 9, c = i % 9, b = (r / 3) * 3 + c / 3
        let used = rows[r] | cols[c] | boxes[b]
        var n = 0
        for d in 1...9 where used & (1 << d) == 0 { n += 1 }
        if n == 0 { return i }
        if n < bestCount { bestCount = n; best = i }
    }
    return best
}
```

`fillComplete` 用泛型 rng 直接 `&rng` 传入 `search`。`countSolutions` / `solvedValues` 声明一个 `var dummy = SystemRandomNumberGenerator()` 但不走 randomize。

把 `Engine/SudokuSolver.swift` 加入两处 Shared `membershipExceptions`。

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter SudokuSolverTests`
Expected: PASS。若 `testCountSolutions_ambiguousIsTwo` 失败（清空后只留一个 1 仍可能唯一），改夹具：两个对称可互换的空格。做法：完整盘挖掉两个数字相同且互换仍合法的格子——更简单：把 `g` 设成只有前两行填满、其余全空，`limit: 2` 必为 2。

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Engine/SudokuSolver.swift" shuduTests/Tests
git commit -m "feat: add bitmask sudoku solver and uniqueness counter"
```

---

### Task 3: 人类手法评级 + 提示格选择

**Files:**
- Modify: `shudu Shared/Engine/SudokuSolver.swift`
- Create: `shuduTests/Tests/SudokuRatingTests.swift`

**Interfaces:**
- Consumes: `SudokuSolver.countSolutions`, `SudokuBoard`
- Produces:
  - `SudokuSolver.rate(givens: [Int?]) -> Difficulty` — 未用手法解完则 `.hard`（唯一性由调用方保证）
  - `SudokuSolver.findHintIndex(values: [Int?]) -> Int?` — 先 Naked/Hidden Single，否则最小空格下标；无空格返回 nil
  - `SudokuSolver.candidates(values: [Int?]) -> [Set<Int>]` — 81 个候选集，已填格为空集

- [ ] **Step 1: 写失败测试**

```swift
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
        let hard = Fixtures.givens([
            ".......1.",
            "4........",
            ".2.......",
            "....5.4.7",
            "..8...3..",
            "..1.9....",
            "3..4..2..",
            ".5.1.....",
            "...8.6..."
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
```

若 `hard17` 的 `countSolutions` 不是 1：换一组已知 17 线索唯一盘，或从 `fillComplete` 挖到评级 hard 再固化数组。不要留随机测试。

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter SudokuRatingTests`
Expected: FAIL，`rate` 不存在

- [ ] **Step 3: 实现手法**

在 `SudokuSolver` 增加候选与循环应用。逻辑必须按 spec：

1. 只用 Naked Single + Hidden Single 能填满 → easy  
2. 再加上 Naked Pair、Hidden Pair、Pointing 能填满 → medium  
3. 否则 → hard  

实现要点（写进同一个文件）：

- `candidates`：每空格 `{1...9}` 减去同行/列/宫已填。
- 循环直到无进度：
  - Naked Single：候选 count==1 则填入
  - Hidden Single：对每个单元每个数字，若只出现在一格则填入
- Intermediate 额外每轮：
  - Naked Pair：单元内两格候选集相等且 count==2，从该单元其他格剔除这两数字
  - Hidden Pair：单元内两数字恰好落在同一两格，把这两格候选收成这两数字
  - Pointing：宫内数字 d 只出现在某一行（或列），从该行（列）宫外剔除 d
- 填入后重建候选。`rate`：先 `apply(through: .singles)`，满则 easy；再从原始 givens `apply(through: .intermediate)`，满则 medium；否则 hard。
- `findHintIndex`：在**当前 values**（含玩家填数）上算候选；若有 Naked Single 返回该下标（最小下标）；否则 Hidden Single 最小下标；否则 `values.firstIndex(where: { $0 == nil })`。

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter SudokuRatingTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Engine/SudokuSolver.swift" shuduTests/Tests/SudokuRatingTests.swift
git commit -m "feat: rate puzzles by human techniques and pick hint cells"
```

---

### Task 4: 生成器

**Files:**
- Create: `shudu Shared/Engine/SudokuGenerator.swift`
- Create: `shuduTests/Tests/SudokuGeneratorTests.swift`

**Interfaces:**
- Consumes: `SudokuSolver.fillComplete`, `countSolutions`, `rate`, `Difficulty.givenFloor`
- Produces:
  - `nonisolated struct Puzzle: Equatable, Sendable { var givens: [Int?]; var solution: [Int]; var difficulty: Difficulty }`
  - `SudokuGenerator.generate(difficulty: Difficulty, deadline: Date, rng: inout some RandomNumberGenerator) -> Puzzle?`
  - 返回的 `Puzzle.difficulty` **等于请求档位**（即使实际评级不同，HUD 用请求档）。`givens` 中非 nil 的位置必须等于 `solution` 同下标。`countSolutions(givens)==1`。`solution` 通过 `isValidComplete`。
  - 超时仍应尽量返回本轮唯一盘；只有连完整盘都没有时返回 nil

- [ ] **Step 1: 写失败测试**

```swift
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
```

不要断言 20 轮内评级必命中。

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter SudokuGeneratorTests`
Expected: FAIL

- [ ] **Step 3: 按 spec 挖空流程实现**

```swift
nonisolated enum SudokuGenerator: Sendable {
    static func generate(
        difficulty: Difficulty,
        deadline: Date,
        rng: inout some RandomNumberGenerator
    ) -> Puzzle? {
        var lastUnique: Puzzle?
        for _ in 0..<20 {
            if Date() > deadline { break }
            guard let solution = SudokuSolver.fillComplete(rng: &rng) else { continue }
            var givens: [Int?] = solution.map { $0 }
            var order = Array(0..<81)
            order.shuffle(using: &rng)
            var givenCount = 81
            for i in order {
                if Date() > deadline { break }
                if givenCount <= difficulty.givenFloor { break }
                let saved = givens[i]
                givens[i] = nil
                if SudokuSolver.countSolutions(values: givens, limit: 2) == 1 {
                    givenCount -= 1
                } else {
                    givens[i] = saved
                }
            }
            givens = adjust(givens, solution: solution, difficulty: difficulty, rng: &rng, deadline: deadline)
            lastUnique = Puzzle(givens: givens, solution: solution, difficulty: difficulty)
            if SudokuSolver.countSolutions(values: givens, limit: 2) == 1,
               SudokuSolver.rate(givens: givens) == difficulty {
                return lastUnique
            }
        }
        return lastUnique
    }
}
```

`adjust` 必须实现 spec 步骤 5：

- 求 easy 却更难：随机把 `solution[i]` 填回空格，直到 `rate == .easy` 或没有空格
- 求 medium 却 easy：继续洗牌挖空（唯一解）直到 medium 或不能再挖
- 求 medium 却 hard：填回直到 medium
- 求 hard 却更易：继续挖直到 hard 或不能再挖
- 每步看 `deadline`

把 `Engine/SudokuGenerator.swift` 加入两处 Shared `membershipExceptions`。

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter SudokuGeneratorTests`
Expected: PASS，8 秒内结束。若超时把测试 `timeout` 调到 15s 但生成器 deadline 仍是调用方传入的 8s。

再跑全量：`swift test --package-path shuduTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Engine/SudokuGenerator.swift" shuduTests/Tests/SudokuGeneratorTests.swift
git commit -m "feat: generate unique sudoku puzzles by difficulty"
```

---

### Task 5: GameState 填数 / 笔记 / 冲突 / 清除

**Files:**
- Modify: `shudu Shared/Game/GameCommand.swift`
- Create: `shudu Shared/Game/GameState.swift`
- Create: `shuduTests/Tests/GameStatePlayTests.swift`

**Interfaces:**
- Consumes: `Cell`, `Puzzle`, `Difficulty`, `SudokuBoard.peers`
- Produces:
  - `nonisolated enum Overlay: Equatable, Sendable { case none; case newGame(allowsCancel: Bool); case win }`
  - `nonisolated enum GameAction: Equatable, Sendable` 至少：`selectCell(Int)`, `tapDigit(Int)`, `clear`, `toggleNotes`, `hint`, `undo`, `redo`, `newGame`, `chooseDifficulty(Difficulty)`, `cancelOverlay`, `tick(TimeInterval)`, `applyGenerated(Puzzle, generationID: UInt)`, `generationFailed(generationID: UInt)`, `appDidEnterBackground`, `appDidBecomeActive`
  - `nonisolated struct GameState: Equatable, Sendable` 字段按 spec；`mutating func dispatch(_ action: GameAction)`
  - `var conflictIndices: Set<Int>` 计算属性
  - `var isWon: Bool`
  - `static func newSession() -> GameState` — overlay `.newGame(allowsCancel: false)`，puzzle nil

- [ ] **Step 1: 写失败测试**

用固定 `Puzzle`：`givens` 为 Task 2 那道著名题，`solution` 为 `Fixtures.complete`，`difficulty: .easy`。

```swift
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
```

`testPlaceDigit_clearsPeerNotes` 里确认 index 2 与所选第二格互为 peers（`SudokuBoard.peers(of: 2)` 包含它）。index 2 是空格（著名题第一行 `53..7` 的第三格）。

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter GameStatePlayTests`
Expected: FAIL

- [ ] **Step 3: 实现 dispatch 的选中/填数/笔记/清除**

`applyGenerated`：写入 puzzle、cells（given 位置 `isGiven=true` value=given，其余空）、`hintsRemaining = difficulty.hintCount`、冲突 0、计时 0、`timerRunning=false`、undo/redo 空、`selectedIndex=nil`、`isNotesMode=false`、`isGenerating=false`、`overlay=.none`。

`placeDigit`：未选中或 given → return。笔记模式且 value==nil → toggle note，push undo。非笔记：写入数字，清本格 notes，从 peers notes 剔除该数字；若写入后该格在 `conflictIndices` 中则 `conflictCount += 1`。清空 redo。

冲突判定：`cell.value != nil` 且 peers 中存在相同 value。

`newSession()`：`generationID = 1`，`overlay = .newGame(allowsCancel: false)`，`isGenerating = false`，cells 81 个空 Cell。

本任务 **不要** 实现 hint/undo/win/timer 的完整行为；`dispatch` 对这些 action 可以 `break` 空实现，测试不覆盖它们。

把 `Game/GameState.swift` 加入两处 Shared `membershipExceptions`。

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter GameStatePlayTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Game" shuduTests/Tests/GameStatePlayTests.swift
git commit -m "feat: place digits, notes, and conflict counting"
```

---

### Task 6: 提示、撤销/重做、胜利

**Files:**
- Modify: `shudu Shared/Game/GameState.swift`
- Create: `shuduTests/Tests/GameStateHintUndoTests.swift`

**Interfaces:**
- Consumes: `SudokuSolver.findHintIndex`, `GameState.dispatch`
- Produces: 完整 `hint` / `undo` / `redo`；满盘无冲突时 `overlay = .win`，`timerRunning = false`；`UndoRecord` 含格子差分、`hintsRemaining` 变化、`conflictCount` 变化（撤销提示不改变 conflictCount，因提示不加计数）

- [ ] **Step 1: 写失败测试**

```swift
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
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter GameStateHintUndoTests`
Expected: FAIL

- [ ] **Step 3: 实现**

- 命令记录：`struct Mutation: Equatable { var index: Int; var before: Cell; var after: Cell }` 以及 `peerNotes: [(Int, Set<Int>)]`，`hintDelta: Int`，`conflictDelta: Int`
- `hint`：`hintsRemaining==0` 或无空格 → return。`findHintIndex` 得下标，按 solution 填入（走与 placeDigit 相同的笔记剔除），`hintsRemaining -= 1`，**不要**加 conflictCount。未选中也允许。
- 每次成功的 place/clear/toggleNote/hint push undo、清 redo。
- `undo`/`redo` 反向/正向应用 mutation，并加减 hint/conflict deltas。
- 每次盘面变化后 `if cells.allSatisfy({ $0.value != nil }) && conflictIndices.isEmpty { overlay = .win; timerRunning = false }`

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --package-path shuduTests --filter GameStateHintUndoTests`
Expected: PASS  
全量：`swift test --package-path shuduTests` PASS

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Game/GameState.swift" shuduTests/Tests/GameStateHintUndoTests.swift
git commit -m "feat: hints, undo/redo, and win detection"
```

---

### Task 7: 新局遮罩、计时、后台生成对接

**Files:**
- Modify: `shudu Shared/Game/GameState.swift`
- Create: `shuduTests/Tests/GameStateSessionTests.swift`

**Interfaces:**
- Consumes: 已有 `dispatch`
- Produces:
  - `formattedElapsed: String` — `< 3600` 用 `m:ss`（分钟不强制两位），`>= 3600` 用 `h:mm:ss`
  - `newGame` → overlay `.newGame(allowsCancel: puzzle != nil)`
  - `chooseDifficulty` → `isGenerating=true`，`generationID += 1`，记下 `pendingDifficulty`，遮罩仍为 newGame（UI 用 `isGenerating` 显示「出题中…」）
  - `applyGenerated` 若 `generationID` 不匹配则忽略
  - `generationFailed` 匹配 ID 时 `isGenerating=false`，overlay 留在 newGame，设 `generationFailed = true`（UI 显示「出题失败」+ 重试即再 `chooseDifficulty`）
  - `tick`：仅 `timerRunning` 时累加
  - 首次成功改变盘面后 `timerRunning=true`；overlay!=none 或 isGenerating 或 background 时暂停；`appDidBecomeActive` 在 overlay==none && !isGenerating && 已开过表 时恢复
  - overlay!=none 或 isGenerating 时忽略 select/digit/clear/hint/notes（`chooseDifficulty`/`cancelOverlay` 除外；生成中忽略 `cancelOverlay`）

- [ ] **Step 1: 写失败测试**

```swift
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
```

Spec：「再来一局」回到难度选择。已胜利的盘不算进行中，**取消无意义**，`allowsCancel: false`。把这条写进 `newGame`：若 `overlay == .win || puzzle == nil` 则 `allowsCancel: false`。

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --package-path shuduTests --filter GameStateSessionTests`
Expected: FAIL

- [ ] **Step 3: 实现上述 session 行为**

`formattedElapsed`：

```swift
var formattedElapsed: String {
    let t = Int(elapsed)
    if t >= 3600 {
        return String(format: "%d:%02d:%02d", t/3600, (t%3600)/60, t%60)
    }
    return String(format: "%d:%02d", t/60, t%60)
}
```

- [ ] **Step 4: 跑全量测试**

Run: `swift test --package-path shuduTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "shudu Shared/Game/GameState.swift" shuduTests/Tests/GameStateSessionTests.swift
git commit -m "feat: new-game overlay, timer, and generation handshake"
```

---

### Task 8: SpriteKit 棋盘与格子

**Files:**
- Create: `shudu Shared/UI/Palette.swift`
- Create: `shudu Shared/UI/CellNode.swift`
- Create: `shudu Shared/UI/BoardNode.swift`
- Modify: `shudu Shared/GameScene.swift`（先能显示空棋盘，下一步再接完整 HUD）

**Interfaces:**
- Consumes: `GameState`, `Cell`, `Palette`
- Produces:
  - `enum Palette` 静态色：`background 1C1916`, `paper EFE4CC`, `ink 2B2118`, `userInk 3D5C8A`, `selected D7C49A`, `peer F4EAD4`, `sameDigit E4D4A8`, `conflictFill F0C8B4`, `conflictInk 8A2A1A`, `note 7A6A58`, `key 2A2420`, `hintKey 3A4A38`, `noteOn D4B483`, `line 3A2F24`
  - `CellNode(index:)` `func apply(cell:selected:peer:sameDigit:conflict:)`
  - `BoardNode` 81 个 CellNode；`func layout(side: CGFloat)`；`func refresh(_ state: GameState)`；`func cellIndex(at scenePoint: CGPoint) -> Int?`
  - 底色优先级：conflict > selected > sameDigit > peer > paper。冲突选中加 `lineWidth = 2` 深墨描边
  - 给定粗体深墨，手填半粗蓝墨，笔记 3×3 SKLabelNode 字号约 side/4.5
  - 字体：`Palatino-Bold` / `Palatino-Roman`，创建失败则 `Georgia-Bold` / `Georgia`

- [ ] **Step 1: 实现 Palette + CellNode + BoardNode**

`Palette.swift` 用 `SKColor(red:green:blue:alpha:)` 把 spec 的 hex 写成 0–1。

`BoardNode`：9×9 格线 0.5pt，宫线 2pt，都是 `SKShapeNode`。格子从左上开始：SpriteKit y 向上，**row 0 在顶部**：`x = (col+0.5)*cell`, `y = side - (row+0.5)*cell`。

把 `UI/Palette.swift`、`UI/CellNode.swift`、`UI/BoardNode.swift` 加入两处 Shared `membershipExceptions`。

- [ ] **Step 2: GameScene 临时只加棋盘，确认能编译**

`GameScene.newGameScene()` **不要** `SKScene(fileNamed:)`：

```swift
class func newGameScene() -> GameScene {
    let scene = GameScene(size: CGSize(width: 390, height: 844))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = Palette.background
    return scene
}
```

`didMove` 里 `addChild(BoardNode())`，`didChangeSize` 里 `board.layout(side: min(size.width, size.height) * 0.92)` 并居中。最小 side 288。

- [ ] **Step 3: 编译 iOS 与 macOS**

Run:

```
xcodebuild -project shudu.xcodeproj -scheme "shudu iOS" -destination 'generic/platform=iOS Simulator' build
xcodebuild -project shudu.xcodeproj -scheme "shudu macOS" -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED。Shared 新文件若没进 target：Xcode synchronized group 应自动包含；若没有，把 UI 目录确认放在 `shudu Shared/` 下。

- [ ] **Step 4: Commit**

```bash
git add "shudu Shared/UI" "shudu Shared/GameScene.swift"
git commit -m "feat: draw sudoku board cells in SpriteKit"
```

---

### Task 9: HUD、数字键、遮罩、Scene 输入与生成

**Files:**
- Create: `shudu Shared/UI/HUDNode.swift`
- Create: `shudu Shared/UI/NumberPadNode.swift`
- Create: `shudu Shared/UI/NewGameOverlayNode.swift`
- Modify: `shudu Shared/GameScene.swift`

**Interfaces:**
- Consumes: `GameState.dispatch`, `SudokuGenerator.generate`
- Produces: 可玩对局
  - 竖排 `height >= width`：HUD 顶、棋盘中、键 1–9+清一行、笔记/撤销/提示/新局一行
  - 横排：棋盘左，右侧 HUD + 3×3 数字 + 清/笔记/撤销 + 提示/新局
  - Overlay 全屏半透明，卡片：三档「简单 · 提示 3」等；`allowsCancel` 时加「取消」；`isGenerating` 只显示「出题中…」；`generationFailed` 显示「出题失败」和「重试」（重试 dispatch 同一个 pendingDifficulty）；win 显示用时、冲突、剩余提示、「再来一局」（dispatch `.newGame`）
  - iOS：`touchesBegan` 命中格子/键；撤销 `touchesBegan` 起 0.45s 定时器，到点则 redo 并标记，`touchesEnded` 若未触发则 undo
  - macOS：`mouseDown` 同点击；`keyDown` 映射 1–9、Delete、n、h、cmd+z、cmd+shift+z
  - `update`：`dispatch(.tick(dt))` 然后 `refresh` 各节点
  - 生成：`chooseDifficulty` 之后

```swift
let id = state.generationID
let diff = state.pendingDifficulty!
Task.detached {
    var rng = SystemRandomNumberGenerator()
    let puzzle = SudokuGenerator.generate(
        difficulty: diff,
        deadline: Date().addingTimeInterval(8),
        rng: &rng
    )
    await MainActor.run {
        if let puzzle {
            scene.state.dispatch(.applyGenerated(puzzle, generationID: id))
        } else {
            scene.state.dispatch(.generationFailed(generationID: id))
        }
    }
}
```

`GameScene` 必须 `@MainActor` 或仅在主线程改 `state`。`GameState` 是 nonisolated struct，Scene 持有 `var state = GameState.newSession()`。

后台：`#if os(iOS)` 听 `UIApplication.didEnterBackgroundNotification` / `didBecomeActiveNotification`；macOS 听 `NSApplication.didResignActiveNotification` / `didBecomeActiveNotification`。不要在 Engine 里 import 这些框架。

NumberPad 用 `name` 识别：`digit-1`…`digit-9`、`clear`、`notes`、`undo`、`hint`、`newGame`。

把 `UI/HUDNode.swift`、`UI/NumberPadNode.swift`、`UI/NewGameOverlayNode.swift` 加入两处 Shared `membershipExceptions`。

- [ ] **Step 1: 实现三个 Node + 重写 GameScene**

删掉 `label` / `spinnyNode` / `makeSpinny` 和模板 touch 里对它们的引用。

布局函数 `layoutPortrait` / `layoutLandscape` 在 `didMove` 与 `didChangeSize` 调用。

- [ ] **Step 2: 编译两端**

Run: 与 Task 8 相同的两条 `xcodebuild`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 跑回归测试**

Run: `swift test --package-path shuduTests`
Expected: PASS（UI 不进 SPM）

- [ ] **Step 4: Commit**

```bash
git add "shudu Shared/UI" "shudu Shared/GameScene.swift"
git commit -m "feat: wire HUD, number pad, overlays, and input"
```

---

### Task 10: 平台入口打磨与手工验收

**Files:**
- Modify: `shudu iOS/GameViewController.swift`
- Modify: `shudu macOS/GameViewController.swift`

**Interfaces:**
- Consumes: `GameScene.newGameScene()`
- Produces: 无调试叠加的可发布窗口

- [ ] **Step 1: iOS GameViewController**

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    let scene = GameScene.newGameScene()
    let skView = self.view as! SKView
    skView.presentScene(scene)
    skView.ignoresSiblingOrder = true
    skView.showsFPS = false
    skView.showsNodeCount = false
}
```

保留 `prefersStatusBarHidden = true`。横竖屏已在工程里允许。

- [ ] **Step 2: macOS GameViewController**

同样关掉 FPS/nodeCount。在 `viewDidAppear`：

```swift
if let window = view.window {
    window.minSize = NSSize(width: 480, height: 640)
    window.makeFirstResponder(view)
}
```

- [ ] **Step 3: 编译两端**

Run: 两条 `xcodebuild` build  
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 手工验收（模拟器或 Mac 运行）**

按这个清单点，缺一条就修，不要标完成：

1. 启动只有难度选择，无取消
2. 选「简单」出现「出题中…」，随后棋盘有给定深墨数字，HUD 显示「简单 / 0:00 / 冲突 0 / 提示 3」
3. 点空格再点数字，手填为蓝墨；点给定格再点数字，给定不变
4. 打开笔记，空格出现小候选；再填同行同数，候选被剔除
5. 故意在已有 5 的行再填 5，两格赤陶，冲突变为 1；改对后高亮消失、次数仍为 1
6. 点提示，一格变成正解，提示 2；撤销后空格回来、提示 3
7. 计时在第一次改盘后走动；点新局遮罩时暂停；取消回盘面继续
8. 旋转 iPhone 或拉 Mac 窗口：竖排/横排切换，棋盘仍是正方形
9. Mac：键盘 1–9、Delete、N、H、⌘Z
10. 用提示或填满使无冲突满盘，出现胜利卡，再来一局回到难度选择

- [ ] **Step 5: Commit**

```bash
git add "shudu iOS/GameViewController.swift" "shudu macOS/GameViewController.swift"
git commit -m "chore: disable debug overlays and set Mac window minimum"
```

---

## Spec coverage (self-review)

| Spec 条目 | Task |
|-----------|------|
| 随机唯一解生成、8s/20 轮、给定下限 | 4 |
| 手法评级 easy/medium/hard | 3 |
| 提示 3/2/1、填正解、可撤销 | 1, 6 |
| 笔记开关、peers 剔除 | 5 |
| 冲突高亮与次数不回退 | 5 |
| 撤销/重做、iOS 长按、Mac ⌘Z | 6, 9 |
| 计时格式、暂停条件 | 7, 9 |
| 满盘无冲突胜利 | 6 |
| 新局遮罩、出题中、出题失败、generationID | 7, 9 |
| 自适应竖/横 | 9 |
| 色值与底色优先级 | 8 |
| 棋盘最小 288、Mac minSize | 8, 10 |
| Engine 单测 1–10 | 1–7 |
| 关掉 FPS、代码构建 Scene | 8, 10 |
| 后台生成 | 9 |
