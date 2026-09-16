import Foundation

nonisolated struct Puzzle: Equatable, Sendable {
    var givens: [Int?]
    var solution: [Int]
    var difficulty: Difficulty
}

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
            if SudokuSolver.countSolutions(values: givens, limit: 2) == 1 {
                lastUnique = Puzzle(givens: givens, solution: solution, difficulty: difficulty)
                if SudokuSolver.rate(givens: givens) == difficulty {
                    return lastUnique
                }
            }
        }
        return lastUnique
    }

    private static func adjust(
        _ givens: [Int?],
        solution: [Int],
        difficulty: Difficulty,
        rng: inout some RandomNumberGenerator,
        deadline: Date
    ) -> [Int?] {
        var givens = givens
        switch difficulty {
        case .easy:
            fillBack(&givens, solution: solution, untilNotHarderThan: .easy, rng: &rng, deadline: deadline)
        case .medium:
            let rated = SudokuSolver.rate(givens: givens)
            if rated == .easy {
                dig(&givens, untilNotEasierThan: .medium, rng: &rng, deadline: deadline)
            } else if rated == .hard {
                fillBack(&givens, solution: solution, untilNotHarderThan: .medium, rng: &rng, deadline: deadline)
            }
        case .hard:
            dig(&givens, untilNotEasierThan: .hard, rng: &rng, deadline: deadline)
        }
        return givens
    }

    private static func fillBack(
        _ givens: inout [Int?],
        solution: [Int],
        untilNotHarderThan target: Difficulty,
        rng: inout some RandomNumberGenerator,
        deadline: Date
    ) {
        var holes = (0..<81).filter { givens[$0] == nil }
        holes.shuffle(using: &rng)
        var k = 0
        while Date() <= deadline, k < holes.count {
            if !isHarder(SudokuSolver.rate(givens: givens), than: target) { return }
            let i = holes[k]
            k += 1
            givens[i] = solution[i]
            // One cell can jump past the requested band (hard→easy while targeting medium).
            if isEasier(SudokuSolver.rate(givens: givens), than: target) {
                givens[i] = nil
            }
        }
    }

    private static func dig(
        _ givens: inout [Int?],
        untilNotEasierThan target: Difficulty,
        rng: inout some RandomNumberGenerator,
        deadline: Date
    ) {
        var filled = (0..<81).filter { givens[$0] != nil }
        filled.shuffle(using: &rng)
        var idx = 0
        while Date() <= deadline, idx < filled.count {
            if !isEasier(SudokuSolver.rate(givens: givens), than: target) { return }
            var progressed = false
            while idx < filled.count {
                if Date() > deadline { return }
                let i = filled[idx]
                idx += 1
                let saved = givens[i]
                givens[i] = nil
                if SudokuSolver.countSolutions(values: givens, limit: 2) == 1 {
                    // One cell can jump past the requested band (easy→hard while targeting medium).
                    if isHarder(SudokuSolver.rate(givens: givens), than: target) {
                        givens[i] = saved
                        continue
                    }
                    progressed = true
                    break
                }
                givens[i] = saved
            }
            if !progressed { return }
        }
    }

    private static func isHarder(_ a: Difficulty, than b: Difficulty) -> Bool {
        rank(a) > rank(b)
    }

    private static func isEasier(_ a: Difficulty, than b: Difficulty) -> Bool {
        rank(a) < rank(b)
    }

    private static func rank(_ d: Difficulty) -> Int {
        switch d {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        }
    }
}
