import SpriteKit

final class NewGameOverlayNode: SKNode {
    private var sceneSize: CGSize = .zero
    private var contentRect: CGRect = .zero
    private var hits: [(rect: CGRect, action: GameAction)] = []
    private var presentedKey: String?

    override init() {
        super.init()
        zPosition = 100
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(sceneSize: CGSize, contentRect: CGRect) {
        self.sceneSize = sceneSize
        self.contentRect = contentRect
        childNode(withName: "confetti-left")?.position = CGPoint(x: 0, y: sceneSize.height * 0.52)
        childNode(withName: "confetti-right")?.position = CGPoint(x: sceneSize.width, y: sceneSize.height * 0.52)
    }

    func refresh(_ state: GameState) {
        let key = presentationKey(state)
        if key == presentedKey { return }
        presentedKey = key
        removeAllChildren()
        hits.removeAll()

        switch state.overlay {
        case .none, .settings:
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
            fireConfetti()
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

    private func presentationKey(_ state: GameState) -> String {
        let look = Palette.appearance == .light ? "L" : "D"
        switch state.overlay {
        case .none, .settings:
            return "\(look)-off"
        case .newGame(let cancel):
            if state.isGenerating { return "\(look)-gen-\(cancel)" }
            if state.generationFailed {
                return "\(look)-fail-\(state.pendingDifficulty?.rawValue ?? "")-\(cancel)"
            }
            return "\(look)-pick-\(cancel)"
        case .win:
            return "\(look)-win-\(state.formattedElapsed)-\(state.conflictCount)-\(state.hintsRemaining)"
        }
    }

    private func addDim() {
        let dim = SKSpriteNode(color: Palette.background.withAlphaComponent(0.78), size: sceneSize)
        dim.anchorPoint = .zero
        dim.position = .zero
        dim.zPosition = 0
        addChild(dim)
    }

    private func fireConfetti() {
        let midY = sceneSize.height * 0.52
        let left = ConfettiCannon.node(
            from: CGPoint(x: 0, y: midY),
            angle: 0.42
        )
        left.name = "confetti-left"
        addChild(left)

        let right = ConfettiCannon.node(
            from: CGPoint(x: sceneSize.width, y: midY),
            angle: .pi - 0.42
        )
        right.name = "confetti-right"
        addChild(right)
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

        let bounds = contentRect.width > 0 ? contentRect : CGRect(origin: .zero, size: sceneSize)
        let cardX = bounds.minX + (bounds.width - cardW) / 2
        let cardY = bounds.minY + (bounds.height - cardH) / 2
        let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
        let card = SKShapeNode(
            path: CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        )
        card.fillColor = Palette.paper
        card.strokeColor = SKColor.clear
        card.zPosition = 10
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
                label.position = CGPoint(x: cardX + cardW / 2, y: y - headerLineH / 2)
                label.zPosition = 12
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
        shape.zPosition = 12
        addChild(shape)

        let label = SKLabelNode(text: title)
        label.fontName = BoardFont.regular
        label.fontColor = prominent ? Palette.paper : Palette.ink
        label.fontSize = 17
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        label.zPosition = 13
        addChild(label)
    }
}

private struct OverlayRow {
    var title: String
    var action: GameAction
    var prominent: Bool
}

enum ConfettiCannon {
    static func node(from origin: CGPoint, angle: CGFloat) -> SKNode {
        let root = SKNode()
        root.position = origin
        root.zPosition = 5
        let colors: [SKColor] = [
            SKColor(red: 0.91, green: 0.36, blue: 0.61, alpha: 1),
            SKColor(red: 0.95, green: 0.65, blue: 0.77, alpha: 1),
            SKColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
            SKColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1),
            SKColor(red: 0.36, green: 0.55, blue: 0.93, alpha: 1),
            SKColor(red: 0.91, green: 0.45, blue: 0.32, alpha: 1)
        ]
        for (i, color) in colors.enumerated() {
            let emitter = SKEmitterNode()
            emitter.particleTexture = i % 2 == 0 ? rectTexture : squareTexture
            emitter.particleBirthRate = 16
            emitter.numParticlesToEmit = 0
            emitter.particleLifetime = 3.2
            emitter.particleLifetimeRange = 0.8
            emitter.emissionAngle = angle
            emitter.emissionAngleRange = 1.05
            emitter.particleSpeed = 280
            emitter.particleSpeedRange = 140
            emitter.yAcceleration = -220
            emitter.particleAlpha = 1
            emitter.particleAlphaSpeed = -0.22
            emitter.particleScale = 0.7
            emitter.particleScaleRange = 0.4
            emitter.particleRotation = 0
            emitter.particleRotationRange = .pi
            emitter.particleRotationSpeed = 8
            emitter.particleColor = color
            emitter.particleColorBlendFactor = 1
            emitter.particleBlendMode = .alpha
            emitter.zPosition = 0
            root.addChild(emitter)
        }
        return root
    }

    private static let rectTexture = makeTexture(width: 8, height: 16)
    private static let squareTexture = makeTexture(width: 10, height: 10)

    private static func makeTexture(width: Int, height: Int) -> SKTexture {
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}
