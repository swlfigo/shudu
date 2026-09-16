import SpriteKit

class GameScene: SKScene {
    private let board = BoardNode()

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = Palette.background
        return scene
    }

    override func didMove(to view: SKView) {
        if board.parent == nil {
            addChild(board)
        }
        layoutBoard()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutBoard()
    }

    private func layoutBoard() {
        let side = max(min(size.width, size.height) * 0.92, 288)
        board.layout(side: side)
        board.position = CGPoint(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2
        )
    }
}
