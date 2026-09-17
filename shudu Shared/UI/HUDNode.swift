import SpriteKit

final class HUDNode: SKNode {
    private let difficultyLabel = SKLabelNode()
    private let timeLabel = SKLabelNode()
    private let conflictLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()
    private let settingsLabel = SKLabelNode()
    private var settingsHit = CGRect.zero

    override init() {
        super.init()
        for label in [difficultyLabel, timeLabel, conflictLabel, hintLabel] {
            label.fontName = BoardFont.regular
            label.fontColor = Palette.hudText
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
        settingsLabel.fontName = BoardFont.regular
        settingsLabel.fontColor = Palette.hudText
        settingsLabel.verticalAlignmentMode = .center
        settingsLabel.horizontalAlignmentMode = .center
        settingsLabel.text = "设置"
        settingsLabel.name = "settings"
        addChild(settingsLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(size: CGSize, compact: Bool) {
        let settingsW = min(56, max(48, size.width * 0.14))
        let statsW = max(0, size.width - settingsW)
        let fontSize = compact ? min(16, size.height * 0.36) : min(18, size.height * 0.5)
        for label in [difficultyLabel, timeLabel, conflictLabel, hintLabel, settingsLabel] {
            label.fontSize = fontSize
        }
        settingsLabel.fontSize = min(fontSize, 16)

        if compact {
            let w = statsW / 2
            let h = size.height / 2
            difficultyLabel.position = CGPoint(x: w * 0.5, y: h * 1.5)
            timeLabel.position = CGPoint(x: w * 1.5, y: h * 1.5)
            conflictLabel.position = CGPoint(x: w * 0.5, y: h * 0.5)
            hintLabel.position = CGPoint(x: w * 1.5, y: h * 0.5)
        } else {
            let w = statsW / 4
            let y = size.height / 2
            difficultyLabel.position = CGPoint(x: w * 0.5, y: y)
            timeLabel.position = CGPoint(x: w * 1.5, y: y)
            conflictLabel.position = CGPoint(x: w * 2.5, y: y)
            hintLabel.position = CGPoint(x: w * 3.5, y: y)
        }

        settingsLabel.position = CGPoint(x: statsW + settingsW / 2, y: size.height / 2)
        settingsHit = CGRect(x: statsW, y: 0, width: settingsW, height: size.height)
    }

    func refresh(_ state: GameState) {
        applyPalette()
        let difficulty = state.puzzle?.difficulty ?? state.pendingDifficulty
        difficultyLabel.text = difficulty?.displayName ?? ""
        timeLabel.text = state.formattedElapsed
        conflictLabel.text = "冲突 \(state.conflictCount)"
        hintLabel.text = "提示 \(state.hintsRemaining)"
    }

    func applyPalette() {
        for label in [difficultyLabel, timeLabel, conflictLabel, hintLabel, settingsLabel] {
            label.fontColor = Palette.hudText
        }
    }

    func controlName(at scenePoint: CGPoint) -> String? {
        guard let scene else { return nil }
        let local = convert(scenePoint, from: scene)
        if settingsHit.contains(local) {
            return "settings"
        }
        return nil
    }
}
