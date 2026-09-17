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
    private let settings = SettingsOverlayNode()


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

    func applyAppearance() {
        Palette.appearance = ThemePreference.current.resolved(systemIsDark: systemIsDark)
        backgroundColor = Palette.background
#if os(iOS)
        view?.backgroundColor = Palette.background
#elseif os(macOS)
        view?.wantsLayer = true
        view?.layer?.backgroundColor = Palette.background.cgColor
#endif
        board.applyPalette()
        hud.applyPalette()
        pad.applyPalette()
        refreshAll()
    }

    private var systemIsDark: Bool {
#if os(iOS)
        view?.traitCollection.userInterfaceStyle == .dark
#elseif os(macOS)
        view?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
#else
        true
#endif
    }

    override func didMove(to view: SKView) {
        applyAppearance()
        if board.parent == nil {
            hud.zPosition = 120
            settings.zPosition = 110
            overlay.zPosition = 100
            addChild(board)
            addChild(hud)
            addChild(pad)
            addChild(overlay)
            addChild(settings)
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
        relayout()
    }

    func relayout() {
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
        let inset = layoutInsets()
        let content = CGRect(
            x: inset.left,
            y: inset.bottom,
            width: max(0, size.width - inset.left - inset.right),
            height: max(0, size.height - inset.top - inset.bottom)
        )
        overlay.layout(sceneSize: size, contentRect: content)
        settings.layout(sceneSize: size, contentRect: content)
        if size.height >= size.width {
            layoutPortrait(inset: inset)
        } else {
            layoutLandscape(inset: inset)
        }
    }

    /// Scene-space padding: view safe area (notch / Dynamic Island / home indicator / landscape ears) plus a 8pt gap, floored at 14pt.
    private func layoutInsets() -> (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        let margin: CGFloat = 14
        let extra: CGFloat = 8
#if os(iOS)
        let safe = view?.safeAreaInsets ?? .zero
        return (
            top: max(margin, safe.top + extra),
            left: max(margin, safe.left + extra),
            bottom: max(margin, safe.bottom + extra),
            right: max(margin, safe.right + extra)
        )
#else
        return (top: margin, left: margin, bottom: margin, right: margin)
#endif
    }

    private func layoutPortrait(inset: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat)) {
        let gap: CGFloat = 10
        let hudH: CGFloat = 36
        let padH: CGFloat = 100
        let contentW = max(0, size.width - inset.left - inset.right)

        hud.position = CGPoint(x: inset.left, y: size.height - inset.top - hudH)
        hud.layout(size: CGSize(width: contentW, height: hudH), compact: false)

        pad.position = CGPoint(x: inset.left, y: inset.bottom)
        pad.layoutPortrait(size: CGSize(width: contentW, height: padH))

        let yMin = inset.bottom + padH + gap
        let yMax = size.height - inset.top - hudH - gap
        let availH = max(0, yMax - yMin)
        let side = max(min(contentW, availH), 288)
        board.layout(side: side)
        board.position = CGPoint(
            x: inset.left + (contentW - side) / 2,
            y: yMin + (availH - side) / 2
        )
    }

    private func layoutLandscape(inset: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat)) {
        let gap: CGFloat = 12
        let hudH: CGFloat = 52
        let padMinWidth: CGFloat = 180
        let contentW = max(0, size.width - inset.left - inset.right)
        let contentH = max(0, size.height - inset.top - inset.bottom)
        var boardSide = min(contentH, contentW * 0.62)
        if contentW - boardSide - gap < padMinWidth {
            boardSide = contentW - padMinWidth - gap
        }
        boardSide = max(min(boardSide, contentH), 288)

        board.layout(side: boardSide)
        board.position = CGPoint(
            x: inset.left,
            y: inset.bottom + (contentH - boardSide) / 2
        )

        let colX = inset.left + boardSide + gap
        let colW = max(size.width - colX - inset.right, padMinWidth)
        hud.position = CGPoint(x: colX, y: size.height - inset.top - hudH)
        hud.layout(size: CGSize(width: colW, height: hudH), compact: true)

        let padH = max(0, contentH - hudH - gap)
        pad.position = CGPoint(x: colX, y: inset.bottom)
        pad.layoutLandscape(size: CGSize(width: colW, height: padH))
    }

    private func refreshAll() {
        board.refresh(state)
        hud.refresh(state)
        pad.refresh(state)
        overlay.refresh(state)
        settings.refresh(state)
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
        if hud.controlName(at: point) == "settings" {
            dispatch(state.overlay == .settings ? .closeSettings : .openSettings)
            return
        }
        if state.overlay == .settings {
            if let hit = settings.action(at: point) {
                handleSettings(hit)
            }
            return
        }
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

    private func handleSettings(_ hit: SettingsOverlayNode.SettingsHit) {
        switch hit {
        case .close:
            dispatch(.closeSettings)
        case .theme(let preference):
            ThemePreference.current = preference
            applyAppearance()
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
        if hud.controlName(at: point) == "settings" {
            dispatch(state.overlay == .settings ? .closeSettings : .openSettings)
            return
        }
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
