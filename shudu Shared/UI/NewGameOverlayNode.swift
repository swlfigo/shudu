import SpriteKit

final class NewGameOverlayNode: SKNode {
    private var sceneSize: CGSize = .zero
    private var hits: [(rect: CGRect, action: GameAction)] = []

    override init() {
        super.init()
        zPosition = 100
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(sceneSize: CGSize) {
        self.sceneSize = sceneSize
    }

    func refresh(_ state: GameState) {
        removeAllChildren()
        hits.removeAll()

        switch state.overlay {
        case .none:
            isHidden = true
            return
        case .newGame(let allowsCancel):
            isHidden = false
            addDim()
            if state.isGenerating {
                presentCard(rows: [], headers: ["出题中…"])
            } else if state.generationFailed {
                var rows: [OverlayRow] = []
                if let pending = state.pendingDifficulty {
                    rows.append(OverlayRow(title: "重试", action: .chooseDifficulty(pending), prominent: true))
                }
                presentCard(rows: rows, headers: ["出题失败"])
            } else {
                var rows: [OverlayRow] = Difficulty.allCases.map { difficulty in
                    OverlayRow(
                        title: "\(difficulty.displayName) · 提示 \(difficulty.hintCount)",
                        action: .chooseDifficulty(difficulty),
                        prominent: true
                    )
                }
                if allowsCancel {
                    rows.append(OverlayRow(title: "取消", action: .cancelOverlay, prominent: false))
                }
                presentCard(rows: rows, headers: [])
            }
        case .win:
            isHidden = false
            addDim()
            presentCard(
                rows: [OverlayRow(title: "再来一局", action: .newGame, prominent: true)],
                headers: [
                    "用时 \(state.formattedElapsed)",
                    "冲突 \(state.conflictCount)",
                    "提示 \(state.hintsRemaining)"
                ]
            )
        }
    }

    func action(at scenePoint: CGPoint) -> GameAction? {
        guard !isHidden, let scene else { return nil }
        let local = convert(scenePoint, from: scene)
        for hit in hits.reversed() {
            if hit.rect.contains(local) {
                return hit.action
            }
        }
        return nil
    }

    private func addDim() {
        let dim = SKSpriteNode(color: Palette.background.withAlphaComponent(0.78), size: sceneSize)
        dim.anchorPoint = .zero
        dim.position = .zero
        dim.zPosition = 0
        addChild(dim)
    }

    private func presentCard(rows: [OverlayRow], headers: [String]) {
        let cardW = min(300, max(220, sceneSize.width * 0.78))
        let buttonH: CGFloat = 44
        let gap: CGFloat = 10
        let pad: CGFloat = 20
        let headerLineH: CGFloat = 26
        let headerH = CGFloat(headers.count) * headerLineH
        let rowsH = CGFloat(rows.count) * buttonH + CGFloat(max(rows.count - 1, 0)) * gap
        let innerGap: CGFloat = !headers.isEmpty && !rows.isEmpty ? 16 : 0
        let cardH = pad * 2 + headerH + innerGap + rowsH

        let cardX = (sceneSize.width - cardW) / 2
        let cardY = (sceneSize.height - cardH) / 2
        let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
        let card = SKShapeNode(
            path: CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        )
        card.fillColor = Palette.paper
        card.strokeColor = SKColor.clear
        card.zPosition = 1
        addChild(card)

        var y = cardY + cardH - pad
        if !headers.isEmpty {
            for line in headers {
                let label = SKLabelNode(text: line)
                label.fontName = BoardFont.regular
                label.fontColor = Palette.ink
                label.fontSize = headers.count == 1 ? 20 : 18
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: sceneSize.width / 2, y: y - headerLineH / 2)
                label.zPosition = 2
                addChild(label)
                y -= headerLineH
            }
            y -= innerGap
        }

        for row in rows {
            y -= buttonH
            let rect = CGRect(x: cardX + pad, y: y, width: cardW - pad * 2, height: buttonH)
            addButton(title: row.title, rect: rect, prominent: row.prominent)
            hits.append((rect: rect, action: row.action))
            y -= gap
        }
    }

    private func addButton(title: String, rect: CGRect, prominent: Bool) {
        let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let shape = SKShapeNode(path: path)
        if prominent {
            shape.fillColor = Palette.ink
            shape.strokeColor = SKColor.clear
            shape.lineWidth = 0
        } else {
            shape.fillColor = Palette.paper
            shape.strokeColor = Palette.ink
            shape.lineWidth = 1.5
        }
        shape.zPosition = 2
        addChild(shape)

        let label = SKLabelNode(text: title)
        label.fontName = BoardFont.regular
        label.fontColor = prominent ? Palette.paper : Palette.ink
        label.fontSize = 17
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        label.zPosition = 3
        addChild(label)
    }
}

private struct OverlayRow {
    var title: String
    var action: GameAction
    var prominent: Bool
}
