import CoreText
import SpriteKit

final class CellNode: SKNode {
    let index: Int

    private let fillNode = SKShapeNode()
    private let valueLabel = SKLabelNode()
    private let noteLabels: [SKLabelNode]

    init(index: Int) {
        self.index = index
        noteLabels = (1...9).map { digit in
            let label = SKLabelNode(text: "\(digit)")
            label.fontName = BoardFont.regular
            label.fontColor = Palette.note
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1
            label.isHidden = true
            return label
        }
        super.init()

        fillNode.fillColor = Palette.paper
        fillNode.strokeColor = SKColor.clear
        fillNode.lineWidth = 0
        fillNode.zPosition = 0
        addChild(fillNode)

        valueLabel.fontName = BoardFont.bold
        valueLabel.fontColor = Palette.ink
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.zPosition = 1
        valueLabel.isHidden = true
        addChild(valueLabel)

        for label in noteLabels {
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(side: CGFloat) {
        let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
        fillNode.path = CGPath(rect: rect, transform: nil)
        valueLabel.fontSize = side * 0.64

        let noteSide = side / 3
        let noteSize = side / 4.5
        for (i, label) in noteLabels.enumerated() {
            let row = i / 3
            let col = i % 3
            label.fontSize = noteSize
            label.position = CGPoint(
                x: (CGFloat(col) + 0.5) * noteSide - side / 2,
                y: side / 2 - (CGFloat(row) + 0.5) * noteSide
            )
        }
    }

    func apply(cell: Cell, selected: Bool, peer: Bool, sameDigit: Bool, conflict: Bool) {
        if conflict {
            fillNode.fillColor = Palette.conflictFill
        } else if selected {
            fillNode.fillColor = Palette.selected
        } else if sameDigit {
            fillNode.fillColor = Palette.sameDigit
        } else if peer {
            fillNode.fillColor = Palette.peer
        } else {
            fillNode.fillColor = Palette.paper
        }

        if conflict && selected {
            fillNode.lineWidth = 2
            fillNode.strokeColor = Palette.ink
        } else {
            fillNode.lineWidth = 0
            fillNode.strokeColor = SKColor.clear
        }

        if let value = cell.value {
            valueLabel.text = "\(value)"
            valueLabel.isHidden = false
            valueLabel.fontName = cell.isGiven ? BoardFont.bold : BoardFont.regular
            if conflict {
                valueLabel.fontColor = Palette.conflictInk
            } else if cell.isGiven {
                valueLabel.fontColor = Palette.ink
            } else {
                valueLabel.fontColor = Palette.userInk
            }
            for label in noteLabels {
                label.isHidden = true
            }
        } else {
            valueLabel.isHidden = true
            for (i, label) in noteLabels.enumerated() {
                label.isHidden = !cell.notes.contains(i + 1)
            }
        }
    }
}

enum BoardFont {
    static let bold = pick(preferred: "Palatino-Bold", fallback: "Georgia-Bold")
    static let regular = pick(preferred: "Palatino-Roman", fallback: "Georgia")

    private static func pick(preferred: String, fallback: String) -> String {
        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []
        return names.contains(preferred) ? preferred : fallback
    }
}
