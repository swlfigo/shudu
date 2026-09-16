nonisolated enum SudokuSolver: Sendable {
    static func countSolutions(values: [Int?], limit: Int) -> Int {
        guard var board = normalizedBoard(values) else { return 0 }
        var rows = [UInt16](repeating: 0, count: 9)
        var cols = [UInt16](repeating: 0, count: 9)
        var boxes = [UInt16](repeating: 0, count: 9)
        guard seedMasks(board, &rows, &cols, &boxes) else { return 0 }
        var found = 0
        var dummy = SystemRandomNumberGenerator()
        _ = search(&board, &rows, &cols, &boxes, &found, limit, randomize: false, rng: &dummy)
        return found
    }

    static func solvedValues(from givens: [Int?]) -> [Int]? {
        guard var board = normalizedBoard(givens) else { return nil }
        var rows = [UInt16](repeating: 0, count: 9)
        var cols = [UInt16](repeating: 0, count: 9)
        var boxes = [UInt16](repeating: 0, count: 9)
        guard seedMasks(board, &rows, &cols, &boxes) else { return nil }
        var found = 0
        var dummy = SystemRandomNumberGenerator()
        _ = search(&board, &rows, &cols, &boxes, &found, 1, randomize: false, rng: &dummy)
        guard found == 1 else { return nil }
        return board.map { $0! }
    }

    static func fillComplete(rng: inout some RandomNumberGenerator) -> [Int]? {
        var board = [Int?](repeating: nil, count: 81)
        var rows = [UInt16](repeating: 0, count: 9)
        var cols = [UInt16](repeating: 0, count: 9)
        var boxes = [UInt16](repeating: 0, count: 9)
        var found = 0
        guard search(&board, &rows, &cols, &boxes, &found, 1, randomize: true, rng: &rng) else {
            return nil
        }
        return board.map { $0! }
    }

    private static func normalizedBoard(_ values: [Int?]) -> [Int?]? {
        guard values.count == 81 else { return nil }
        return values
    }

    private static func seedMasks(
        _ board: [Int?],
        _ rows: inout [UInt16],
        _ cols: inout [UInt16],
        _ boxes: inout [UInt16]
    ) -> Bool {
        for i in 0..<81 {
            guard let d = board[i] else { continue }
            guard (1...9).contains(d) else { return false }
            let r = i / 9, c = i % 9, b = (r / 3) * 3 + c / 3
            let bit = UInt16(1) << d
            if rows[r] & bit != 0 || cols[c] & bit != 0 || boxes[b] & bit != 0 {
                return false
            }
            rows[r] |= bit
            cols[c] |= bit
            boxes[b] |= bit
        }
        return true
    }

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
        if randomize, let rng {
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
}
