//
//  GameViewController.swift
//  shudu macOS
//
//  Created by sylar on 2026/9/16.
//

import Cocoa
import SpriteKit
import GameplayKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = GameScene.newGameScene()

        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true

        skView.showsFPS = false
        skView.showsNodeCount = false
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            window.minSize = NSSize(width: 480, height: 640)
            window.makeFirstResponder(view)
        }
    }

}
