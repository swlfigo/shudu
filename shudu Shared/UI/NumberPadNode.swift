import SpriteKit

final class NumberPadNode: SKNode {
    private let keys: [KeyNode]
    private let keysByName: [String: KeyNode]

    override init() {
        var built: [KeyNode] = []
        for digit in 1...9 {
            built.append(KeyNode(identifier: "digit-\(digit)", title: "\(digit)", fillColor: Palette.key))
        }
        built.append(KeyNode(identifier: "clear", title: "清", fillColor: Palette.key))
        built.append(KeyNode(identifier: "notes", title: "笔记", fillColor: Palette.key))
        built.append(KeyNode(identifier: "undo", title: "撤销", fillColor: Palette.key))
        built.append(KeyNode(identifier: "hint", title: "提示", fillColor: Palette.hintKey))
        built.append(KeyNode(identifier: "newGame", title: "新局", fillColor: Palette.key))
        keys = built
        keysByName = Dictionary(uniqueKeysWithValues: built.map { ($0.identifier, $0) })
        super.init()
        for key in keys {
            addChild(key)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layoutPortrait(size: CGSize) {
        let gap: CGFloat = 6
        let rowH = (size.height - gap) / 2
        let digits = (1...9).map { "digit-\($0)" } + ["clear"]
        place(digits, origin: CGPoint(x: 0, y: rowH + gap), size: CGSize(width: size.width, height: rowH), columns: 10, gap: gap)
        place(["notes", "undo", "hint", "newGame"], origin: .zero, size: CGSize(width: size.width, height: rowH), columns: 4, gap: gap)
    }

    func layoutLandscape(size: CGSize) {
        let gap: CGFloat = 6
        let controlH = min(44, max(32, size.height * 0.15))
        let controlsH = controlH * 2 + gap
        let gridBudget = max(0, size.height - controlsH - gap)
        let key = min(64, (size.width - 2 * gap) / 3, (gridBudget - 2 * gap) / 3)
        let gridW = key * 3 + gap * 2
        let gridH = gridW
        let gridX = (size.width - gridW) / 2
        let gridY = controlsH + gap + max(0, (gridBudget - gridH) / 2)
        place((1...9).map { "digit-\($0)" }, origin: CGPoint(x: gridX, y: gridY), size: CGSize(width: gridW, height: gridH), columns: 3, gap: gap)
        place(["clear", "notes", "undo"], origin: CGPoint(x: 0, y: controlH + gap), size: CGSize(width: size.width, height: controlH), columns: 3, gap: gap)
        place(["hint", "newGame"], origin: .zero, size: CGSize(width: size.width, height: controlH), columns: 2, gap: gap)
    }

    func applyPalette() {
        for key in keys {
            key.applyPalette()
        }
    }

    func refresh(_ state: GameState) {
        applyPalette()
        keysByName["notes"]?.setNotesOn(state.isNotesMode)
        let boardFull = state.cells.allSatisfy { $0.value != nil }
        let hintOn = state.puzzle != nil && state.hintsRemaining > 0 && !boardFull
        keysByName["hint"]?.alpha = hintOn ? 1 : 0.4
        keysByName["undo"]?.alpha = state.undoStack.isEmpty ? 0.4 : 1
    }

    func controlName(at scenePoint: CGPoint) -> String? {
        guard let scene else { return nil }
        let local = convert(scenePoint, from: scene)
        for key in keys {
            let rect = CGRect(origin: key.position, size: key.keySize)
            if rect.contains(local) {
                return key.identifier
            }
        }
        return nil
    }

    private func place(_ ids: [String], origin: CGPoint, size: CGSize, columns: Int, gap: CGFloat) {
        let rows = max(1, (ids.count + columns - 1) / columns)
        let w = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let h = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        for (i, id) in ids.enumerated() {
            let row = i / columns
            let col = i % columns
            let x = origin.x + CGFloat(col) * (w + gap)
            let y = origin.y + size.height - CGFloat(row + 1) * h - CGFloat(row) * gap
            guard let key = keysByName[id] else { continue }
            key.position = CGPoint(x: x, y: y)
            key.layout(size: CGSize(width: w, height: h))
        }
    }
}

private final class KeyNode: SKNode {
    let identifier: String
    private(set) var keySize: CGSize = .zero
    private let fill = SKShapeNode()
    private let label = SKLabelNode()

    init(identifier: String, title: String, fillColor: SKColor) {
        self.identifier = identifier
        super.init()
        name = identifier
        fill.fillColor = fillColor
        fill.strokeColor = SKColor.clear
        fill.lineWidth = 0
        fill.lineJoin = .round
        addChild(fill)

        label.text = title
        label.fontName = BoardFont.regular
        label.fontColor = Palette.keyText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(size: CGSize) {
        keySize = size
        let radius = min(8, min(size.width, size.height) * 0.18)
        let rect = CGRect(origin: .zero, size: size)
        fill.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let title = label.text ?? ""
        label.fontSize = title.count > 1 ? min(16, size.height * 0.36) : min(22, size.height * 0.5)
    }

    func applyPalette() {
        fill.fillColor = identifier == "hint" ? Palette.hintKey : Palette.key
        label.fontColor = Palette.keyText
        if fill.lineWidth > 0 {
            fill.strokeColor = Palette.noteOn
        }
    }

    func setNotesOn(_ on: Bool) {
        if on {
            fill.strokeColor = Palette.noteOn
            fill.lineWidth = 2
        } else {
            fill.strokeColor = SKColor.clear
            fill.lineWidth = 0
        }
    }
}
