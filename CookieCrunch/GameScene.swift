import SpriteKit

class GameScene: SKScene {

  var level: Level!
  var swipeHandler: ((Swap) -> ())?
  var selectionSprite = SKSpriteNode()

  let cropLayer = SKCropNode()
  let maskLayer = SKNode()
  let TileWidth: CGFloat = 32.0
  let TileHeight: CGFloat = 36.0
  let gameLayer = SKNode()
  let cookiesLayer = SKNode()
  let tilesLayer = SKNode()

  private var swipeFromColumn: Int?
  private var swipeFromRow: Int?

  let swapSound = SKAction.playSoundFileNamed("Chomp.wav", waitForCompletion: false)
  let invalidSwapSound = SKAction.playSoundFileNamed("Error.wav", waitForCompletion: false)
  let matchSound = SKAction.playSoundFileNamed("Ka-Ching.wav", waitForCompletion: false)
  let fallingCookieSound = SKAction.playSoundFileNamed("Scrape.wav", waitForCompletion: false)
  let addCookieSound = SKAction.playSoundFileNamed("Drip.wav", waitForCompletion: false)

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder) is not used in this app")
  }

  func animateGameOver(_ completion: @escaping () -> ()) {
    let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .easeIn
    gameLayer.run(action, completion: completion)
  }

  func animateBeginGame(_ completion: @escaping () -> ()) {
    gameLayer.isHidden = false
    gameLayer.position = CGPoint(x: 0, y: size.height)
    let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .easeOut
    gameLayer.run(action, completion: completion)
  }

  override init(size: CGSize) {
    super.init(size: size)

    anchorPoint = CGPoint(x: 0.5, y: 0.5)

    let background = SKSpriteNode(imageNamed: "Background")
    background.size = size

    addChild(background)
    addChild(gameLayer)

    gameLayer.isHidden = true

    let layerPosition = CGPoint(
      x: -TileWidth * CGFloat(NumColumns) / 2,
      y: -TileHeight * CGFloat(NumRows) / 2)

    tilesLayer.position = layerPosition
    gameLayer.addChild(tilesLayer)

    gameLayer.addChild(cropLayer)

    maskLayer.position = layerPosition
    cropLayer.maskNode = maskLayer

    cookiesLayer.position = layerPosition
    cropLayer.addChild(cookiesLayer)

    swipeFromColumn = nil
    swipeFromRow = nil
//    cropLayer.addChild(maskLayer)
    let _ = SKLabelNode(fontNamed: "GillSans-BoldItalic")
  }

  func addTiles() {
    for row in 0..<NumRows {
      for column in 0..<NumColumns {
        if level.tileAt(column: column, row: row) != nil {
          let tileNode = SKSpriteNode(imageNamed: "MaskTile")
          tileNode.size = CGSize(width: TileWidth, height: TileHeight)
          tileNode.position = pointFor(column: column, row: row)
          maskLayer.addChild(tileNode)
        }
      }
    }

    for row in 0...NumRows {
      for column in 0...NumColumns {
        let topLeft     = (column > 0) && (row < NumRows)
          && level.tileAt(column: column - 1, row: row) != nil
        let bottomLeft  = (column > 0) && (row > 0)
          && level.tileAt(column: column - 1, row: row - 1) != nil
        let topRight    = (column < NumColumns) && (row < NumRows)
          && level.tileAt(column: column, row: row) != nil
        let bottomRight = (column < NumColumns) && (row > 0)
          && level.tileAt(column: column, row: row - 1) != nil

        // The tiles are named from 0 to 15, according to the bitmask that is
        // made by combining these four values.
        let value0 =
          Int(topLeft.hashValue) |
            Int(topRight.hashValue) << 1

        let value = value0 | Int(bottomLeft.hashValue) << 2 |
            Int(bottomRight.hashValue) << 3

        // Values 0 (no tiles), 6 and 9 (two opposite tiles) are not drawn.
        if value != 0 && value != 6 && value != 9 {
          let name = String(format: "Tile_%ld", value)
          let tileNode = SKSpriteNode(imageNamed: name)
          tileNode.size = CGSize(width: TileWidth, height: TileHeight)
          var point = pointFor(column: column, row: row)
          point.x -= TileWidth/2
          point.y -= TileHeight/2
          tileNode.position = point
          tilesLayer.addChild(tileNode)
        }
      }
    }
  }

  func animateNewCookies(_ columns: [[Cookie]], completion: @escaping () -> ()) {
    var longestDuration: TimeInterval = 0

    for array in columns {
      let startRow = array[0].row + 1

      for (idx, cookie) in array.enumerated() {
        let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
        sprite.size = CGSize(width: TileWidth, height: TileHeight)
        sprite.position = pointFor(column: cookie.column, row: startRow)
        cookiesLayer.addChild(sprite)
        cookie.sprite = sprite
        let delay = 0.1 + 0.2 * TimeInterval(array.count - idx - 1)
        let duration = TimeInterval(startRow - cookie.row) * 0.1
        longestDuration = max(longestDuration, duration + delay)
        let newPosition = pointFor(column: cookie.column, row: cookie.row)
        let moveAction = SKAction.move(to: newPosition, duration: duration)
        moveAction.timingMode = .easeOut
        sprite.alpha = 0
        sprite.run(
          SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
              SKAction.fadeIn(withDuration: 0.05),
              moveAction,
              addCookieSound])
            ]))
      }
    }
    run(SKAction.wait(forDuration: longestDuration), completion: completion)
  }

  func animateFallingCookiesFor(columns: [[Cookie]], completion: @escaping () -> ()) {
    var longestDuration: TimeInterval = 0
    for array in columns {
      for (idx, cookie) in array.enumerated() {
        let newPosition = pointFor(column: cookie.column, row: cookie.row)
        let delay = 0.05 + 0.15*TimeInterval(idx)
        let sprite = cookie.sprite!   // sprite always exists at this point
        let duration = TimeInterval(((sprite.position.y - newPosition.y) / TileHeight) * 0.1)
        longestDuration = max(longestDuration, duration + delay)
        let moveAction = SKAction.move(to: newPosition, duration: duration)
        moveAction.timingMode = .easeOut
        sprite.run(
          SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([moveAction, fallingCookieSound])]))
      }
    }

    run(SKAction.wait(forDuration: longestDuration), completion: completion)
  }

  func animateMatchedCookies(for chains: Set<Chain>, completion: @escaping () -> ()) {
    for chain in chains {
      animateScore(for: chain)
      for cookie in chain.cookies {
        if let sprite = cookie.sprite {
          if sprite.action(forKey: "removing") == nil {
            let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
            scaleAction.timingMode = .easeOut
            sprite.run(SKAction.sequence([scaleAction, SKAction.removeFromParent()]), withKey:"removing")
          }
        }
      }
    }
    run(matchSound)
    run(SKAction.wait(forDuration: 0.3), completion: completion)
  }

  func animateInvalidSwap(_ swap: Swap, completion: @escaping () -> ()) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!

    spriteA.zPosition = 100
    spriteB.zPosition = 90

    let duration: TimeInterval = 0.2

    let moveA = SKAction.move(to: spriteB.position, duration: duration)
    moveA.timingMode = .easeOut

    let moveB = SKAction.move(to: spriteA.position, duration: duration)
    moveB.timingMode = .easeOut

    spriteA.run(SKAction.sequence([moveA, moveB]), completion: completion)
    spriteB.run(SKAction.sequence([moveB, moveA]))

    run(invalidSwapSound)
  }

  func animateScore(for chain: Chain) {
    let firstSprite = chain.firstCookie().sprite!
    let lastSprite = chain.lastCookie().sprite!
    let centerPosition = CGPoint(
      x: (firstSprite.position.x + lastSprite.position.x)/2,
      y: (firstSprite.position.y + lastSprite.position.y)/2 - 8)

    let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
    scoreLabel.fontSize = 16
    scoreLabel.text = String(format: "%ld", chain.score)
    scoreLabel.position = centerPosition
    scoreLabel.zPosition = 300
    cookiesLayer.addChild(scoreLabel)

    let moveAction = SKAction.move(by: CGVector(dx: 0, dy: 3), duration: 0.7)
    moveAction.timingMode = .easeOut
    scoreLabel.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
  }

  func addSprites(for cookies: Set<Cookie>) {
    for cookie in cookies {
      let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
      sprite.size = CGSize(width: TileWidth, height: TileHeight)
      sprite.position = pointFor(column: cookie.column, row: cookie.row)
      cookiesLayer.addChild(sprite)
      cookie.sprite = sprite

      sprite.alpha = 0
      sprite.xScale = 0.5
      sprite.yScale = 0.5

      sprite.run(
        SKAction.sequence([
          SKAction.wait(forDuration: 0.25, withRange: 0.5),
          SKAction.group([
            SKAction.fadeIn(withDuration: 0.25),
            SKAction.scale(to: 1.0, duration: 0.25)
            ])
          ]))
    }
  }

  func removeAllCookieSprites() {
    cookiesLayer.removeAllChildren()
  }

  func pointFor(column: Int, row: Int) -> CGPoint {
    return CGPoint(
      x: CGFloat(column) * TileWidth + TileWidth / 2,
      y: CGFloat(row) * TileHeight + TileHeight / 2)
  }

  func convertPoint(point: CGPoint) -> (success: Bool, column: Int, row: Int) {
    if point.x >= 0 && point.x < CGFloat(NumColumns)*TileWidth &&
      point.y >= 0 && point.y < CGFloat(NumRows)*TileHeight {
      return (true, Int(point.x / TileWidth), Int(point.y / TileHeight))
    } else {
      return (false, 0, 0)
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }

    let location = touch.location(in: cookiesLayer)
    let (success, column, row) = convertPoint(point: location)

    if success {
      if let cookie = level.cookieAt(column: column, row: row) {
        showSelectionIndicator(for: cookie)
        swipeFromColumn = column
        swipeFromRow = row
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard swipeFromColumn != nil else { return }
    guard let touch = touches.first else { return }

    let location = touch.location(in: cookiesLayer)
    let (success, column, row) = convertPoint(point: location)	
    if success {

      var horzDelta = 0, vertDelta = 0
      if column < swipeFromColumn! { // swipe left
        horzDelta = -1
      } else if column > swipeFromColumn! { // swipe right
        horzDelta = 1
      } else if row < swipeFromRow! { // swipe down
        vertDelta = -1
      } else if row > swipeFromRow! { // swipe up
        vertDelta = 1
      }

      if horzDelta != 0 || vertDelta != 0 {
        trySwap(horizontal: horzDelta, vertical: vertDelta)
        hideSelectionIndicator()
        swipeFromColumn = nil
      }
    }
  }

  func animate(_ swap: Swap, completion: @escaping () -> ()) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!

    spriteA.zPosition = 100
    spriteB.zPosition = 90

    let duration: TimeInterval = 0.3

    let moveA = SKAction.move(to: spriteB.position, duration: duration)
    moveA.timingMode = .easeOut
    spriteA.run(moveA, completion: completion)

    let moveB = SKAction.move(to: spriteA.position, duration: duration)
    moveB.timingMode = .easeOut
    spriteB.run(moveB)
    run(swapSound)
  }

  func trySwap(horizontal horzDelta: Int, vertical vertDelta: Int) {
    let toColumn = swipeFromColumn! + horzDelta
    let toRow = swipeFromRow! + vertDelta

    guard toColumn >= 0 && toColumn < NumColumns else { return }
    guard toRow >= 0 && toRow < NumRows else { return }

    if let toCookie = level.cookieAt(column: toColumn, row: toRow),
      let fromCookie = level.cookieAt(column: swipeFromColumn!, row: swipeFromRow!) {
      if let handler = swipeHandler {
        let swap = Swap(cookieA: fromCookie, cookieB: toCookie)
        handler(swap)
      }
    }
  }

  func hideSelectionIndicator() {
    selectionSprite.run(SKAction.sequence([
      SKAction.fadeOut(withDuration: 0.3),
      SKAction.removeFromParent()]))
  }

  func showSelectionIndicator(for cookie: Cookie) {
    if selectionSprite.parent != nil {
      selectionSprite.removeFromParent()
    }

    if let sprite = cookie.sprite {
      let texture = SKTexture(imageNamed: cookie.cookieType.highlightedSpriteName)
      selectionSprite.size = CGSize(width: TileWidth, height: TileHeight)
      selectionSprite.run(SKAction.setTexture(texture))

      sprite.addChild(selectionSprite)
      selectionSprite.alpha = 1.0
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    swipeFromColumn = nil
    swipeFromRow = nil
    if selectionSprite.parent != nil && swipeFromColumn != nil {
      hideSelectionIndicator()
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
