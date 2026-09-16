import SpriteKit

final class HUDNode: SKNode {
    private let difficultyLabel = SKLabelNode()
    private let timeLabel = SKLabelNode()
    private let conflictLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    override init() {
        super.init()
        for label in [difficultyLabel, timeLabel, conflictLabel, hintLabel] {
            label.fontName = BoardFont.regular
            label.fontColor = Palette.paper
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(size: CGSize, compact: Bool) {
        let fontSize = compact ? min(16, size.height * 0.36) : min(18, size.height * 0.5)
        for label in [difficultyLabel, timeLabel, conflictLabel, hintLabel] {
            label.fontSize = fontSize
        }

        if compact {
            let w = size.width / 2
            let h = size.height / 2
            difficultyLabel.position = CGPoint(x: w * 0.5, y: h * 1.5)
            timeLabel.position = CGPoint(x: w * 1.5, y: h * 1.5)
            conflictLabel.position = CGPoint(x: w * 0.5, y: h * 0.5)
            hintLabel.position = CGPoint(x: w * 1.5, y: h * 0.5)
        } else {
            let w = size.width / 4
            let y = size.height / 2
            difficultyLabel.position = CGPoint(x: w * 0.5, y: y)
            timeLabel.position = CGPoint(x: w * 1.5, y: y)
            conflictLabel.position = CGPoint(x: w * 2.5, y: y)
            hintLabel.position = CGPoint(x: w * 3.5, y: y)
        }
    }

    func refresh(_ state: GameState) {
        let difficulty = state.puzzle?.difficulty ?? state.pendingDifficulty
        difficultyLabel.text = difficulty?.displayName ?? ""
        timeLabel.text = state.formattedElapsed
        conflictLabel.text = "冲突 \(state.conflictCount)"
        hintLabel.text = "提示 \(state.hintsRemaining)"
    }
}
