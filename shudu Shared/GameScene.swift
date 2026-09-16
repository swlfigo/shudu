import SpriteKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
class GameScene: SKScene {
    var state = GameState.newSession()

    private let board = BoardNode()
    private let hud = HUDNode()
    private let pad = NumberPadNode()
    private let overlay = NewGameOverlayNode()

    private var lastUpdateTime: TimeInterval = 0
    private var observersInstalled = false
    private var undoTouchActive = false
    private var undoHoldTriggered = false

    private let undoHoldKey = "undoHold"
    private let undoHoldDuration: TimeInterval = 0.45

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = Palette.background
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = Palette.background
        if board.parent == nil {
            addChild(board)
            addChild(hud)
            addChild(pad)
            addChild(overlay)
        }
        installBackgroundObservers()
        lastUpdateTime = 0
        layoutForCurrentSize()
        refreshAll()
    }

    override func willMove(from view: SKView) {
        cancelUndoHold()
        NotificationCenter.default.removeObserver(self)
        observersInstalled = false
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForCurrentSize()
        refreshAll()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        if dt > 0, dt < 1 {
            state.dispatch(.tick(dt))
        }
        refreshAll()
    }

    private func layoutForCurrentSize() {
        overlay.layout(sceneSize: size)
        if size.height >= size.width {
            layoutPortrait()
        } else {
            layoutLandscape()
        }
    }

    private func layoutPortrait() {
        let margin: CGFloat = 14
        let gap: CGFloat = 10
        let hudH: CGFloat = 36
        let padH: CGFloat = 100

        hud.position = CGPoint(x: margin, y: size.height - margin - hudH)
        hud.layout(size: CGSize(width: size.width - 2 * margin, height: hudH), compact: false)

        pad.position = CGPoint(x: margin, y: margin)
        pad.layoutPortrait(size: CGSize(width: size.width - 2 * margin, height: padH))

        let yMin = margin + padH + gap
        let yMax = size.height - margin - hudH - gap
        let availH = max(0, yMax - yMin)
        let availW = max(0, size.width - 2 * margin)
        let side = max(min(availW, availH), 288)
        board.layout(side: side)
        board.position = CGPoint(
            x: (size.width - side) / 2,
            y: yMin + (availH - side) / 2
        )
    }

    private func layoutLandscape() {
        let margin: CGFloat = 14
        let gap: CGFloat = 12
        let hudH: CGFloat = 52
        let padMinWidth: CGFloat = 180
        let availH = max(0, size.height - 2 * margin)
        var boardSide = min(availH, size.width * 0.62)
        if size.width - boardSide - 2 * margin - gap < padMinWidth {
            boardSide = size.width - padMinWidth - 2 * margin - gap
        }
        boardSide = max(min(boardSide, availH), 288)

        board.layout(side: boardSide)
        board.position = CGPoint(x: margin, y: (size.height - boardSide) / 2)

        let colX = margin + boardSide + gap
        let colW = max(size.width - colX - margin, padMinWidth)
        hud.position = CGPoint(x: colX, y: size.height - margin - hudH)
        hud.layout(size: CGSize(width: colW, height: hudH), compact: true)

        let padH = max(0, size.height - 2 * margin - hudH - gap)
        pad.position = CGPoint(x: colX, y: margin)
        pad.layoutLandscape(size: CGSize(width: colW, height: padH))
    }

    private func refreshAll() {
        board.refresh(state)
        hud.refresh(state)
        pad.refresh(state)
        overlay.refresh(state)
    }

    private var inputBlocked: Bool {
        state.overlay != .none || state.isGenerating
    }

    private func dispatch(_ action: GameAction) {
        let generating: Bool
        if case .chooseDifficulty = action {
            generating = true
        } else {
            generating = false
        }
        state.dispatch(action)
        if generating {
            startGeneration()
        }
        refreshAll()
    }

    private func startGeneration() {
        guard let diff = state.pendingDifficulty else { return }
        let id = state.generationID
        Task { [weak self] in
            let puzzle = await Task.detached {
                var rng = SystemRandomNumberGenerator()
                return SudokuGenerator.generate(
                    difficulty: diff,
                    deadline: Date().addingTimeInterval(8),
                    rng: &rng
                )
            }.value
            guard let self else { return }
            if let puzzle {
                self.state.dispatch(.applyGenerated(puzzle, generationID: id))
            } else {
                self.state.dispatch(.generationFailed(generationID: id))
            }
            self.refreshAll()
        }
    }

    private func handleTap(at point: CGPoint) {
        if inputBlocked {
            if let action = overlay.action(at: point) {
                dispatch(action)
            }
            return
        }
        if let index = board.cellIndex(at: point) {
            dispatch(.selectCell(index))
            return
        }
        if let name = pad.controlName(at: point) {
            performPad(name)
        }
    }

    private func performPad(_ name: String) {
        if name.hasPrefix("digit-"), let digit = Int(name.dropFirst(6)), (1...9).contains(digit) {
            dispatch(.tapDigit(digit))
            return
        }
        switch name {
        case "clear":
            dispatch(.clear)
        case "notes":
            dispatch(.toggleNotes)
        case "undo":
            dispatch(.undo)
        case "hint":
            dispatch(.hint)
        case "newGame":
            dispatch(.newGame)
        default:
            break
        }
    }

    private func beginUndoHold() {
        undoTouchActive = true
        undoHoldTriggered = false
        removeAction(forKey: undoHoldKey)
        let wait = SKAction.wait(forDuration: undoHoldDuration)
        let fire = SKAction.run { [weak self] in
            guard let self else { return }
            self.undoHoldTriggered = true
            self.dispatch(.redo)
        }
        run(SKAction.sequence([wait, fire]), withKey: undoHoldKey)
    }

    private func endUndoHold() {
        guard undoTouchActive else { return }
        let triggered = undoHoldTriggered
        cancelUndoHold()
        if !triggered {
            dispatch(.undo)
        }
    }

    private func cancelUndoHold() {
        removeAction(forKey: undoHoldKey)
        undoTouchActive = false
        undoHoldTriggered = false
    }

#if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first.map({ $0.location(in: self) }) else { return }
        if inputBlocked {
            handleTap(at: point)
            return
        }
        if let index = board.cellIndex(at: point) {
            dispatch(.selectCell(index))
            return
        }
        if let name = pad.controlName(at: point) {
            if name == "undo" {
                beginUndoHold()
            } else {
                performPad(name)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endUndoHold()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelUndoHold()
    }
#endif

#if os(macOS)
    override func mouseDown(with event: NSEvent) {
        handleTap(at: event.location(in: self))
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "z" {
                dispatch(mods.contains(.shift) ? .redo : .undo)
            }
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            dispatch(.clear)
            return
        }
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return }
        if chars == "\u{8}" || chars == "\u{7F}" {
            dispatch(.clear)
            return
        }
        if let digit = Int(chars), (1...9).contains(digit) {
            dispatch(.tapDigit(digit))
            return
        }
        switch chars.lowercased() {
        case "n":
            dispatch(.toggleNotes)
        case "h":
            dispatch(.hint)
        default:
            break
        }
    }
#endif

    private func installBackgroundObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
#elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
#endif
    }

    @objc private func appDidEnterBackground() {
        state.dispatch(.appDidEnterBackground)
        lastUpdateTime = 0
        refreshAll()
    }

    @objc private func appDidBecomeActive() {
        state.dispatch(.appDidBecomeActive)
        lastUpdateTime = 0
        refreshAll()
    }
}
