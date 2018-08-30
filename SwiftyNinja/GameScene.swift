//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by LALIT JAGTAP on 8/7/18.
//  Copyright © 2018 LALIT JAGTAP. All rights reserved.
//

import SpriteKit
import GameplayKit
import  AVFoundation

enum ForceBomb {
    case never, always, random
}

enum SequenceType: Int {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {
    
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    var isSwooshSoundActive = false
    
    var activeEnemeies = [SKSpriteNode]()
    var bombSoundEffect: AVAudioPlayer!    // needed to stop the bomb sound, the SKAction cant do that

    var popupTime = 0.9     // amount of time to wait till last enemy is destroyed and new one is created
    var sequence: [SequenceType]!   // array of sequence type enum to define what eneimes to create
    var sequencePosition = 0    // where we are right now in the game
    var chainDelay = 3.0    // how long to wait when createing a new enemy of type chain of fast chain
    var nextSequenceQueue = true   // when we know all enemies created are destroyed and we are ready to creat more
    
    var gameEnded = false
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        
        addChild(background)

        physicsWorld.gravity = CGVector(dx: 0, dy: -6)      // reduce gravity of vector pointing downward
        physicsWorld.speed = 0.85               // reduce speed of pysical world
        
        createScore()
        createLives()
        createSlices()
        
        
        // now bring the game to life by tossing enemies on screen
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(min: 2, max: 7))!
            sequence.append(nextSequence)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in self.tossEnemies() }
        
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
    }
    
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        // 2 slide shapes in yellow and white
        // z position as 2 ..as slices are above everything
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 2
        
        // slice in yellow color as hot glow
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        // slice in white color
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // remove all existing poinsts because starting new touch / slice
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        // get 1st touch location and add to active slice poinsts
        if let touch = touches.first {
            let location = touch.location(in: self)
            activeSlicePoints.append(location)
            
            // call redraw slice logic to clear slice shapes
            redrawActiveSlice()
            
            // remove any actions attached to slice shapes. very important if they are in middle of fade out action
            activeSliceBG.removeAllActions()
            activeSliceFG.removeAllActions()
            
            // set alpha 1 to make it fully visible
            activeSliceBG.alpha = 1
            activeSliceFG.alpha = 1
        }
    }
    
    // determine user touch location in the scene, add location to slice point array and redraw slice shape
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if gameEnded {
            return
        }
        
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        if !isSwooshSoundActive {
            playSwooshSound()   // play swoosh sound only once
        }
        
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if node.name == "enemy" {
                print ("destroy penguin")
                
                // create a particle effect over the penguin
                let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")!
                emitter.position = node.position
                addChild(emitter)
                
                // clear node name so it can't be swiped repeatedly
                node.name = ""
                
                // clear isDynamic of it's physical property so that it doesn't keep on falling
                node.physicsBody?.isDynamic = false
                
                // make penguin scale out and fade out at same time
                let scaleout = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeout = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleout, fadeout])
                
                // remove dead penguin from scene
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                node.run(seq)
                
                // update score
                score += 1
                
                // remove it from active enemies node array
                let index = activeEnemeies.index(of: node as! SKSpriteNode)!
                activeEnemeies.remove(at: index)
                
                // play the sound of slicing enemy
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))

            } else if node.name == "bomb" {
                print ("destroy bombs")
                
                // create a particle effect over the bomb
                let emitter = SKEmitterNode(fileNamed: "sliceHitBomb")!
                emitter.position = node.parent!.position
                addChild(emitter)
                
                // clear node name so its can't be swipped repeatedly
                node.name = ""
                
                // clear isDynamic of pysical property so it doesn't fall
                node.parent?.physicsBody?.isDynamic = false
                
                // make bomb scale out and fade out at same time using SKAction.group
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                // remove dead bomb from scene
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                
                // it is important to call the parent ...lalit to check more
                node.parent?.run(seq)
                
                // remove it from active enemeis node array
                let index = activeEnemeies.index(of: node.parent as! SKSpriteNode)!
                activeEnemeies.remove(at: index)

                // play the sound of slicing enemy
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggeredByBomb: true)
            }
        }
    }
    
    // make a slice shape fade out over a quarter of a second
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    // if due to any system event, the slice needs to fade out
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    func redrawActiveSlice() {
        
        // redraw a slice shape if more than 2 touches
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        // remove oldest point if we have more than 12 points to keep swipe shape being too long
        while activeSlicePoints.count > 12 {
            activeSlicePoints.remove(at: 0)
        }
        
        // start a line at position of first swipe point and go through each point, to draw a line
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        // update slice shape so they get drawn using width and color
        activeSliceFG.path = path.cgPath
        activeSliceBG.path = path.cgPath
    }
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = RandomInt(min: 1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        
        // wait for completion of swoodh sound play
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        // only enable the swoosh sound replay again after earlier one is complete
        run(swooshSound) { [unowned self] in
            self.isSwooshSoundActive = false
        }
    }
    
    // create an enmey as bomb or no bomb or random ...accept it as parameter
    // based on parameter create a bomb or penguin
    // determine where to be created on screen
    // what direction should it be moving
    // add enemy to scene and active array of enemies
    func createEnemy(forceBomb: ForceBomb = .random) {
        
        // accept [arameter to force a bomb, or not or random as default
        
        var enemy: SKSpriteNode
        var enemyType = RandomInt(min: 0, max: 6)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            // create bomb code is here
            // a bomb node is made up of 3 parts, bomb image, fuse particle emiiter and container
            // a container holds both together so we can move and spin it together
            
            enemy = SKSpriteNode()
            enemy.zPosition = 1         // important to make bomb appear above penguin
            enemy.name = "bombContainer"
            
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            // if bomb sound is playing, than stop and destroy it
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
            
            // create a new bomb sound effect and play it
            let path = Bundle.main.path(forResource: "sliceBombFuse.caf", ofType: nil)!
            let url = URL(fileURLWithPath: path)
            let sound = try! AVAudioPlayer(contentsOf: url)
            bombSoundEffect = sound
            sound.play()
            
            // create a particle emiiter code, position it at end of bomb image fuse and add to container
            let emitter = SKEmitterNode(fileNamed: "sliceFuse")!
            emitter.position = CGPoint(x: 76, y: 64)
            enemy.addChild(emitter)
            
        } else {
            // no bomb ..so create a penguin
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        // determine enemy position as per code below
        
        // give enemy a random position at bottom of screen
        let randomPosition = CGPoint(x: RandomInt(min: 64, max: 960), y: -128)
        enemy.position = randomPosition
        
        // create a random angular velocty for enemy to how fast to spin
        let randomAngularVelocity = CGFloat(RandomInt(min: -6, max: 6)) / 2.0
        
        // create x velocity to take into account how fast to move horizontally
        var randomXVelocity = 0
        if randomPosition.x < 256 {
            randomXVelocity = RandomInt(min: 8, max: 15)
        } else if randomPosition.x < 512 {
            randomXVelocity = RandomInt(min: 3, max: 5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -RandomInt(min: 3, max: 5)
        } else {
            randomXVelocity = -RandomInt(min: 8, max: 15)
        }
        
        // create a y velocity to fly off things at differnt speeds
        let randomYVelocity = RandomInt(min: 24, max: 32)
        
        // give all enemies a circular body, and set collision as zero so they dont collide
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0

        addChild(enemy)
        activeEnemeies.append(enemy)
    }
    
    // its called for every frame before it is drawn
    // use it to count no. of bomb containers exists in our game and stop fuse sound if zero bomb
    override func update(_ currentTime: TimeInterval) {
        
        // remove enemies from screen when they fall off
        if activeEnemeies.count > 0 {
            for node in activeEnemeies {
                if node.position.y < -140 {
                    // reduce the life if the penguin drops off the screen

                    node.removeAllActions()
                    
                    if node.name == "enemy" {
                        
                        subtractLife()

                        node.name = ""
                        node.removeFromParent()

                        if let index = activeEnemeies.index(of: node) {
                            activeEnemeies.remove(at: index)
                        }
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemeies.index(of: node) {
                            activeEnemeies.remove(at: index)
                        }
                    }
                }
            }
        } else {
            // no enemies on screen and we havn't aleadey scheduled next enemy sequence
            // than schedule next enemies sequence and setup a flag about scheduled next sequence
            if !nextSequenceQueue {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [unowned self] in self.tossEnemies()}
                nextSequenceQueue = true
            }
        }
        
        var bombCount = 0
        
        for node in activeEnemeies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            // no bombs - stop the fuse sound
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
    }
    
    // to create enemies, and also make a it difficult from being gentle to fast the enemies creations
    // reduce the popup time and chain delay time, and also increase the speed of physical world
    func tossEnemies () {
        
        if gameEnded {
            return
        }
        
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [unowned self] in self.createEnemy() }
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [unowned self] in self.createEnemy() }
        }
        
        sequencePosition += 1
        nextSequenceQueue = false
    }
    
    // reduce no of lives and update the life gone count of 3 at top right of screen using texture
    func subtractLife() {
        lives -= 1
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)     //ended due to 3 lives over
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration: 0.1))
    }
    
    // game can end due to slicing on bomb or due lives are over
    // end the pysiscal world of a game scene and disable user interaction too
    func endGame(triggeredByBomb: Bool) {
        if gameEnded {
            return
        }
        
        gameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
    }
}
