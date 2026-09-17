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

    static func candidates(values: [Int?]) -> [Set<Int>] {
        guard values.count == 81 else { return [] }
        var rowUsed = [Set<Int>](repeating: [], count: 9)
        var colUsed = [Set<Int>](repeating: [], count: 9)
        var boxUsed = [Set<Int>](repeating: [], count: 9)
        for i in 0..<81 {
            guard let d = values[i] else { continue }
            rowUsed[i / 9].insert(d)
            colUsed[i % 9].insert(d)
            boxUsed[SudokuBoard.box(i)].insert(d)
        }
        let all = Set(1...9)
        var result = [Set<Int>](repeating: [], count: 81)
        for i in 0..<81 where values[i] == nil {
            result[i] = all
                .subtracting(rowUsed[i / 9])
                .subtracting(colUsed[i % 9])
                .subtracting(boxUsed[SudokuBoard.box(i)])
        }
        return result
    }

    static func rate(givens: [Int?]) -> Difficulty {
        guard givens.count == 81 else { return .hard }
        if isComplete(apply(givens, through: .singles)) { return .easy }
        if isComplete(apply(givens, through: .intermediate)) { return .medium }
        return .hard
    }

    static func findHintIndex(values: [Int?]) -> Int? {
        guard values.count == 81 else { return values.firstIndex(where: { $0 == nil }) }
        let cands = candidates(values: values)
        if let i = cands.indices.first(where: { cands[$0].count == 1 }) {
            return i
        }
        var hidden: Int?
        for unit in units {
            for d in 1...9 {
                var found: Int?
                var count = 0
                for i in unit where cands[i].contains(d) {
                    count += 1
                    found = i
                    if count > 1 { break }
                }
                if count == 1, let i = found {
                    hidden = hidden.map { min($0, i) } ?? i
                }
            }
        }
        return hidden ?? values.firstIndex(where: { $0 == nil })
    }

    private enum TechniqueLevel {
        case singles
        case intermediate
    }

    private static let rows: [[Int]] = (0..<9).map { r in (0..<9).map { c in r * 9 + c } }
    private static let cols: [[Int]] = (0..<9).map { c in (0..<9).map { r in r * 9 + c } }
    private static let boxes: [[Int]] = (0..<9).map { b in
        let br = (b / 3) * 3, bc = (b % 3) * 3
        return (0..<9).map { (br + $0 / 3) * 9 + (bc + $0 % 3) }
    }
    private static let units: [[Int]] = rows + cols + boxes

    private static func isComplete(_ values: [Int?]) -> Bool {
        values.count == 81 && values.allSatisfy { $0 != nil }
    }

    private static func apply(_ givens: [Int?], through level: TechniqueLevel) -> [Int?] {
        var values = givens
        var cands = candidates(values: values)
        while true {
            if fillNakedSingle(&values, cands) {
                cands = candidates(values: values)
                continue
            }
            if fillHiddenSingle(&values, cands) {
                cands = candidates(values: values)
                continue
            }
            if level == .intermediate {
                if eliminateNakedPairs(&cands) { continue }
                if eliminateHiddenPairs(&cands) { continue }
                if eliminatePointing(&cands) { continue }
            }
            break
        }
        return values
    }

    private static func fillNakedSingle(_ values: inout [Int?], _ cands: [Set<Int>]) -> Bool {
        for i in 0..<81 where values[i] == nil && cands[i].count == 1 {
            values[i] = cands[i].first
            return true
        }
        return false
    }

    private static func fillHiddenSingle(_ values: inout [Int?], _ cands: [Set<Int>]) -> Bool {
        for unit in units {
            for d in 1...9 {
                var found: Int?
                var count = 0
                for i in unit where values[i] == nil && cands[i].contains(d) {
                    count += 1
                    found = i
                    if count > 1 { break }
                }
                if count == 1, let i = found {
                    values[i] = d
                    return true
                }
            }
        }
        return false
    }

    private static func eliminateNakedPairs(_ cands: inout [Set<Int>]) -> Bool {
        var progress = false
        for unit in units {
            var groups: [Set<Int>: [Int]] = [:]
            for i in unit where cands[i].count == 2 {
                groups[cands[i], default: []].append(i)
            }
            for (pair, cells) in groups where cells.count == 2 {
                for i in unit where !cells.contains(i) {
                    let before = cands[i].count
                    cands[i].subtract(pair)
                    if cands[i].count != before { progress = true }
                }
            }
        }
        return progress
    }

    private static func eliminateHiddenPairs(_ cands: inout [Set<Int>]) -> Bool {
        var progress = false
        for unit in units {
            var positions = [[Int]](repeating: [], count: 10)
            for i in unit {
                for d in cands[i] { positions[d].append(i) }
            }
            for d1 in 1...8 {
                for d2 in (d1 + 1)...9 {
                    let p1 = positions[d1], p2 = positions[d2]
                    guard p1.count == 2, p1 == p2 else { continue }
                    let pair: Set<Int> = [d1, d2]
                    for i in p1 where cands[i] != pair {
                        cands[i] = pair
                        progress = true
                    }
                }
            }
        }
        return progress
    }

    private static func eliminatePointing(_ cands: inout [Set<Int>]) -> Bool {
        var progress = false
        for (b, box) in boxes.enumerated() {
            for d in 1...9 {
                let spots = box.filter { cands[$0].contains(d) }
                guard spots.count >= 2 else { continue }
                let rs = Set(spots.map { $0 / 9 })
                if rs.count == 1, let r = rs.first {
                    for i in rows[r] where SudokuBoard.box(i) != b {
                        if cands[i].remove(d) != nil { progress = true }
                    }
                }
                let cs = Set(spots.map { $0 % 9 })
                if cs.count == 1, let c = cs.first {
                    for i in cols[c] where SudokuBoard.box(i) != b {
                        if cands[i].remove(d) != nil { progress = true }
                    }
                }
            }
        }
        return progress
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
