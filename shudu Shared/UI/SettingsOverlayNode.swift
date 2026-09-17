import SpriteKit

final class SettingsOverlayNode: SKNode {
    private var sceneSize: CGSize = .zero
    private var contentRect: CGRect = .zero
    private var hits: [(rect: CGRect, hit: SettingsHit)] = []

    enum SettingsHit {
        case close
        case theme(ThemePreference)
        case previewConfetti
    }

    override init() {
        super.init()
        zPosition = 110
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(sceneSize: CGSize, contentRect: CGRect) {
        self.sceneSize = sceneSize
        self.contentRect = contentRect
    }

    func refresh(_ state: GameState) {
        removeAllChildren()
        hits.removeAll()
        guard state.overlay == .settings else {
            isHidden = true
            return
        }
        isHidden = false
        addDim()
        presentCard()
    }

    func action(at scenePoint: CGPoint) -> SettingsHit? {
        guard !isHidden, let scene else { return nil }
        let local = convert(scenePoint, from: scene)
        for item in hits.reversed() {
            if item.rect.contains(local) {
                return item.hit
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

    private func presentCard() {
        let bounds = contentRect.width > 0 ? contentRect : CGRect(origin: .zero, size: sceneSize)
        let cardW = min(320, max(240, bounds.width * 0.82))
        let pad: CGFloat = 20
        let titleH: CGFloat = 28
        let sectionH: CGFloat = 22
        let rowH: CGFloat = 44
        let gap: CGFloat = 8
        let options = ThemePreference.allCases
        let rowsH = CGFloat(options.count) * rowH + CGFloat(options.count - 1) * gap
        let doneH: CGFloat = 44
        let previewH: CGFloat = 44
        let cardH = pad + titleH + 16 + sectionH + 8 + rowsH + 16 + previewH + gap + doneH + pad

        let cardX = bounds.minX + (bounds.width - cardW) / 2
        let cardY = bounds.minY + (bounds.height - cardH) / 2
        let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
        let card = SKShapeNode(
            path: CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        )
        card.fillColor = Palette.paper
        card.strokeColor = SKColor.clear
        card.zPosition = 1
        addChild(card)

        var y = cardY + cardH - pad
        addCenteredLabel("设置", y: y - titleH / 2, size: 22, color: Palette.ink)
        y -= titleH + 16
        addLeftLabel("外观", x: cardX + pad, y: y - sectionH / 2, size: 14, color: Palette.note)
        y -= sectionH + 8

        let selected = ThemePreference.current
        for preference in options {
            y -= rowH
            let rect = CGRect(x: cardX + pad, y: y, width: cardW - pad * 2, height: rowH)
            addOption(title: optionTitle(preference), rect: rect, selected: preference == selected)
            hits.append((rect: rect, hit: .theme(preference)))
            y -= gap
        }

        y -= 8
        y -= previewH
        let previewRect = CGRect(x: cardX + pad, y: y, width: cardW - pad * 2, height: previewH)
        addOption(title: "预览庆祝", rect: previewRect, selected: false)
        hits.append((rect: previewRect, hit: .previewConfetti))
        y -= gap
        y -= doneH
        let doneRect = CGRect(x: cardX + pad, y: y, width: cardW - pad * 2, height: doneH)
        addDone(rect: doneRect)
        hits.append((rect: doneRect, hit: .close))
    }

    private func optionTitle(_ preference: ThemePreference) -> String {
        switch preference {
        case .system: return "跟随系统"
        case .light: return "日间"
        case .dark: return "夜间"
        }
    }

    private func addCenteredLabel(_ text: String, y: CGFloat, size: CGFloat, color: SKColor) {
        let bounds = contentRect.width > 0 ? contentRect : CGRect(origin: .zero, size: sceneSize)
        let label = SKLabelNode(text: text)
        label.fontName = BoardFont.regular
        label.fontColor = color
        label.fontSize = size
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: bounds.midX, y: y)
        label.zPosition = 2
        addChild(label)
    }

    private func addLeftLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color: SKColor) {
        let label = SKLabelNode(text: text)
        label.fontName = BoardFont.regular
        label.fontColor = color
        label.fontSize = size
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 2
        addChild(label)
    }

    private func addOption(title: String, rect: CGRect, selected: Bool) {
        let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let shape = SKShapeNode(path: path)
        if selected {
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
        label.fontColor = selected ? Palette.paper : Palette.ink
        label.fontSize = 17
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        label.zPosition = 3
        addChild(label)
    }

    private func addDone(rect: CGRect) {
        let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let shape = SKShapeNode(path: path)
        shape.fillColor = Palette.ink
        shape.strokeColor = SKColor.clear
        shape.zPosition = 2
        addChild(shape)

        let label = SKLabelNode(text: "完成")
        label.fontName = BoardFont.regular
        label.fontColor = Palette.paper
        label.fontSize = 17
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: rect.midY)
        label.zPosition = 3
        addChild(label)
    }
}
