import SpriteKit

final class BoardNode: SKNode {
    private let cells: [CellNode]
    private let gridLines = SKShapeNode()
    private let boxLines = SKShapeNode()
    private var side: CGFloat = 0

    override init() {
        cells = (0..<SudokuBoard.cellCount).map { CellNode(index: $0) }
        super.init()
        for cell in cells {
            addChild(cell)
        }
        applyPalette()
        gridLines.fillColor = SKColor.clear
        gridLines.lineWidth = 0.5
        gridLines.lineCap = .butt
        gridLines.zPosition = 2
        addChild(gridLines)

        boxLines.fillColor = SKColor.clear
        boxLines.lineWidth = 2
        boxLines.lineCap = .butt
        boxLines.zPosition = 3
        addChild(boxLines)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette() {
        gridLines.strokeColor = Palette.line
        boxLines.strokeColor = Palette.line
    }

    func layout(side: CGFloat) {
        self.side = side
        let cell = side / 9
        for node in cells {
            let row = SudokuBoard.row(node.index)
            let col = SudokuBoard.col(node.index)
            node.position = CGPoint(
                x: (CGFloat(col) + 0.5) * cell,
                y: side - (CGFloat(row) + 0.5) * cell
            )
            node.layout(side: cell)
        }

        let grid = CGMutablePath()
        let boxes = CGMutablePath()
        for i in 0...9 {
            let x = CGFloat(i) * cell
            let y = CGFloat(i) * cell
            let path = i % 3 == 0 ? boxes : grid
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: side))
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: side, y: y))
        }
        gridLines.path = grid
        boxLines.path = boxes
    }

    func refresh(_ state: GameState) {
        applyPalette()
        let selected = state.selectedIndex
        let conflicts = state.conflictIndices
        let selectedValue: Int?
        if let selected, state.cells.indices.contains(selected) {
            selectedValue = state.cells[selected].value
        } else {
            selectedValue = nil
        }
        let peers: Set<Int> = selected.map { Set(SudokuBoard.peers(of: $0)) } ?? []

        for node in cells {
            let i = node.index
            let cell = state.cells.indices.contains(i) ? state.cells[i] : Cell()
            node.apply(
                cell: cell,
                selected: selected == i,
                peer: peers.contains(i),
                sameDigit: selectedValue != nil && cell.value == selectedValue,
                conflict: conflicts.contains(i)
            )
        }
    }

    func cellIndex(at scenePoint: CGPoint) -> Int? {
        guard side > 0, let scene else { return nil }
        let local = convert(scenePoint, from: scene)
        guard local.x >= 0, local.x <= side, local.y >= 0, local.y <= side else { return nil }
        let cell = side / 9
        guard cell > 0 else { return nil }
        let col = min(8, Int(local.x / cell))
        let row = min(8, Int((side - local.y) / cell))
        return row * 9 + col
    }
}
