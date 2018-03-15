import UIKit
import SpriteKit

class GameViewController: UIViewController {

  var scene: GameScene!
  var level: Level!

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override var shouldAutorotate: Bool {
    return true
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return [.portrait, .portraitUpsideDown]
  }

  func handleSwipe(_ swap: Swap) {
    view.isUserInteractionEnabled = false

    if level.isPossibleSwap(swap) {
      level.performSwap(swap: swap)
      scene.animate(swap) {
        self.view.isUserInteractionEnabled = true
      }
    } else {
        scene.animateInvalidSwap(swap) {
        self.view.isUserInteractionEnabled = true
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let skView = view as! SKView
    skView.isMultipleTouchEnabled = false

    scene = GameScene(size: skView.bounds.size)
    scene.scaleMode = .aspectFill

    level = Level(filename: "Level_1")
    scene.level = level
    scene.addTiles()
    scene.swipeHandler = handleSwipe

    skView.presentScene(scene)
    beginGame()
  }

  func beginGame() {
    shuffle()
  }

  func shuffle() {
    let newCookies = level.shuffle()
    scene.addSprites(for: newCookies)
  }
}
