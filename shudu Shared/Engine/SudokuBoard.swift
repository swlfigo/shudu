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
