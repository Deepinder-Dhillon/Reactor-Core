//
//  GameScene.swift
//  ReactorCore
//
//  Created by Deepinder on 2025-05-03.
//

import SpriteKit
import UIKit

class GameScene: SKScene {
    
    // sprite nodes
    private var knobNode: SKSpriteNode!
    private var rod1: SKSpriteNode!
    private var rod2: SKSpriteNode!
    private var rod3: SKSpriteNode!
    private var needleNode: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var surgeBG: SKSpriteNode!
    private var surgeText: SKSpriteNode!
    private var coolantBG: SKSpriteNode!
    private var coolantText: SKSpriteNode!
    
    // knob and haptic
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastTickAngle: CGFloat = 0
    private let tickStep: CGFloat = 0.4
    private let knobTouchRadius: CGFloat = 350
    private var isKnobTouched: Bool = false
    
    // knob rotation and speed
    private var lastKnobAngle: CGFloat = 0
    private var rotation: CGFloat = 0
    private let rotationSpeed: CGFloat = 0.4
    
    // reactor rods
    private let rodMinY: CGFloat = -100
    private let rodMaxY: CGFloat = 150
    private var rod1Position: CGFloat = 0.0
    private var rod2Position: CGFloat = 0.0
    private var rod3Position: CGFloat = 0.0
    private var rod1TargetPosition: CGFloat = 0.0
    private var rod2TargetPosition: CGFloat = 0.0
    private var rod3TargetPosition: CGFloat = 0.0
    private let rodMoveSpeed: CGFloat = 0.05
    private var rod1Speed: CGFloat = 0.8
    private var rod2Speed: CGFloat = 1
    private var rod3Speed: CGFloat = 1.2
    
    
    
    // pressure needle
    private var reactorTemp: CGFloat = 0.5
    private var needleCurAngle: CGFloat = 0.0
    private var heatGenRate: CGFloat = 0.006
    private var coolingRate: CGFloat = 0.005
    private let tempDriftRate: CGFloat = 0.0008
    private let needleSmooth: CGFloat = 0.5
    
    // rod drift
    private var lastMovementTime: TimeInterval = 0
    private let driftDelay: TimeInterval = 0.3
    private var rod1Direction: CGFloat = 1.0
    private var rod2Direction: CGFloat = -1.0
    private let rodDriftSpeed: CGFloat = 0.007
    
    // score
    private var score: CGFloat = 0
    private var lastScoreTime: TimeInterval = 0
    

    private enum ReactorMode { case normal, surge, coolant }

    private var currentMode: String = "normal"
    private var modeLabel: SKLabelNode!
    private var timerLabel: SKLabelNode!
    private var modeStartTime: TimeInterval = 0
    private let modeDuration: TimeInterval = 10

    private var defaultHeatGenRate: CGFloat = 0.006
    private var defaultCoolingRate: CGFloat = 0.005
    private var flipRodMovement = false
    
    // main scene
    override func didMove(to view: SKView) {
        
        guard
            let knob = childNode(withName: "knobNode") as? SKSpriteNode,
            let r1 = childNode(withName: "rod1") as? SKSpriteNode,
            let r2 = childNode(withName: "rod2") as? SKSpriteNode,
            let r3 = childNode(withName: "rod3") as? SKSpriteNode,
            let needle = childNode(withName: "needle") as? SKSpriteNode,
            let lbl = childNode(withName: "ScoreLB") as? SKLabelNode,
            let modeLB = childNode(withName: "mode") as? SKLabelNode,
            let timerLB = childNode(withName: "timer") as? SKLabelNode,
            let surge_bg = childNode(withName: "surge-bg") as? SKSpriteNode,
            let surge_text = childNode(withName: "surge-text") as? SKSpriteNode,
            let coolant_bg = childNode(withName: "coolant-bg") as? SKSpriteNode,
            let coolant_text = childNode(withName: "coolant-text") as? SKSpriteNode
            
        else {
            print("Error: missing nodes")
            return
        }
        knobNode = knob
        rod1 = r1
        rod2 = r2
        rod3 = r3
        needleNode = needle
        scoreLabel = lbl
        modeLabel = modeLB
        timerLabel = timerLB
        surgeBG = surge_bg
        surgeText = surge_text
        coolantBG = coolant_bg
        coolantText = coolant_text
        
        surgeBG.alpha = 0
        surgeText.alpha = 0
        coolantBG.alpha = 0
        coolantText.alpha = 0
        
        
        lastScoreTime = CACurrentMediaTime()
        
        
        haptic.prepare()
        lastTickAngle = knobNode.zRotation
        updateRodPositions()
        let updateAction = SKAction.customAction(withDuration: 1.0/60.0) { [weak self] _, _ in
            self?.updateGameState()
        }
        // run main logic
        run(SKAction.repeatForever(updateAction))
        
        currentMode = "default"
        modeStartTime = CACurrentMediaTime()
        applyMode()
        
        run(
          SKAction.sequence([
            SKAction.wait(forDuration: 20),
            SKAction.run { [weak self] in self?.selectMode() }
          ]),
          withKey: "initialModeTransition"
        )
    }
    
    // init touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let angle = angleBetween(knobCenter: knobNode.position, to: location)
        lastKnobAngle = angle
        
        let distance = distanceBetween(p1: location, p2: knobNode.position)
        if distance <= knobTouchRadius {
            isKnobTouched = true
        }
    }
    // touch handling for knob and rod movement
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isKnobTouched, let touch = touches.first else { return }
        
        let touchLocation = touch.location(in: self)
        let angle = angleBetween(knobCenter: knobNode.position, to: touchLocation)
        let angleDiff = calculateAngleDiff(from: lastKnobAngle, to: angle)
        
        
        rotation += angleDiff * rotationSpeed
        knobNode.zRotation = rotation
        checkForHaptic(newAngle: rotation)
        updateRodTargetPositions(angleDiff: -angleDiff)
        
        
        
        lastKnobAngle = angle
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isKnobTouched = false
        updateRodSpeed()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isKnobTouched = false
    }
    
    // main logic
    private func updateGameState() {
        let avgRodPosition = (rod1Position + rod2Position + rod3Position) / 3
        reactorTemp += avgRodPosition * heatGenRate
        reactorTemp -= (1 - avgRodPosition) * coolingRate
        
        let time = CGFloat(CACurrentMediaTime())
        let drift = sin(time * 0.1) * tempDriftRate + CGFloat.random(in: -0.0005...0.0005)
        reactorTemp =  max(0.0, min(1.0, reactorTemp + drift))
        
        //needle range -120 to 120
        let needleRange: CGFloat = 2.0 * .pi / 3.0
        let targetRotation = needleRange * (reactorTemp * 2 - 1)
        
        needleCurAngle += (targetRotation - needleCurAngle) * needleSmooth
        needleNode.zRotation = needleCurAngle
        
        // move rods
        updateRodPositions()
        let curTime = CACurrentMediaTime()
        
        updateScore()
        
        // add drift if knob not moved
        if  (curTime - lastMovementTime) > driftDelay{
            rodDrift()
            updateRodSpeed()
        }
        
        
    }
    
    // rod movement animation
    private func updateRodPositions() {
        rod1Position += (rod1TargetPosition - rod1Position) * rodMoveSpeed * rod1Speed
        rod2Position += (rod2TargetPosition - rod2Position) * rodMoveSpeed * rod2Speed
        rod3Position += (rod3TargetPosition - rod3Position) * rodMoveSpeed * rod3Speed
        
        rod1?.position.y = rodMinY + (rodMaxY - rodMinY) * rod1Position
        rod2?.position.y = rodMinY + (rodMaxY - rodMinY) * rod2Position
        rod3?.position.y = rodMinY + (rodMaxY - rodMinY) * rod3Position
    }
    
    // rod movement based on knob rotation
    // rod movement based on knob rotation
    private func updateRodTargetPositions(angleDiff: CGFloat) {
        let scaleFactor: CGFloat = 0.08
        let diff = flipRodMovement ? -angleDiff : angleDiff

        if diff > 0 {
            rod1TargetPosition = max(0.0,
              rod1TargetPosition - abs(diff) * scaleFactor * rod1Speed)
            rod2TargetPosition = max(0.0,
              rod2TargetPosition - abs(diff) * scaleFactor * rod2Speed)
            rod3TargetPosition = max(0.0,
              rod3TargetPosition - abs(diff) * scaleFactor * rod3Speed)
        } else {
            rod1TargetPosition = min(1.0,
              rod1TargetPosition + abs(diff) * scaleFactor * rod1Speed)
            rod2TargetPosition = min(1.0,
              rod2TargetPosition + abs(diff) * scaleFactor * rod2Speed)
            rod3TargetPosition = min(1.0,
              rod3TargetPosition + abs(diff) * scaleFactor * rod3Speed)
        }
    }

    
    private func updateRodSpeed() {
        let values: [CGFloat] = [-1,0,1]
        rod1Speed = CGFloat.random(in: 0.7...1.4)
        rod2Speed = CGFloat.random(in: 0.7...1.4)
        rod3Speed = CGFloat.random(in: 0.7...1.4)
        
        if abs(rod1Speed - rod2Speed) < 0.2 {
            rod2Speed = rod1Speed + 0.2 * values.randomElement()!
        }
        if abs(rod1Speed - rod3Speed) < 0.2 {
            rod3Speed = rod1Speed + 0.2 * values.randomElement()!
        }
    }
    
    // triggers haptic
    private func checkForHaptic(newAngle: CGFloat) {
        let delta = calculateAngleDiff(from: lastTickAngle, to: newAngle)
        
        if abs(delta) >= tickStep {
            lastMovementTime = CACurrentMediaTime()
            haptic.impactOccurred()
            haptic.prepare()
            lastTickAngle = newAngle
        }
    }
    
    // helper functions
    private func distanceBetween(p1: CGPoint, p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func angleBetween(knobCenter: CGPoint, to touchPoint: CGPoint) -> CGFloat {
        let dx = touchPoint.x - knobCenter.x
        let dy = touchPoint.y - knobCenter.y
        
        return atan2(dy, dx) - CGFloat.pi / 2
    }
    
    private func easeInOutSine(_ t: CGFloat) -> CGFloat {
        return -(cos(CGFloat.pi * t) - 1) / 2
    }
    
    private func calculateAngleDiff(from startAngle: CGFloat, to endAngle: CGFloat) -> CGFloat {
        var diff = endAngle - startAngle
        
        while diff > .pi {
            diff -= 2 * .pi
        }
        while diff < -.pi {
            diff += 2 * .pi
        }
        return diff
    }
    
    
    private func rodDrift() {
        let time = CGFloat(CACurrentMediaTime())
        
        rod1TargetPosition += rod1Direction * rodDriftSpeed * easeInOutSine(time)
        rod2TargetPosition += rod2Direction * rodDriftSpeed * easeInOutSine(time + 1.0)
        rod3TargetPosition = (rod1TargetPosition + rod2TargetPosition) / 2
        
        if rod1TargetPosition <= 0 || rod1TargetPosition >= 1 {
            rod1Direction *= -1
        }
        if rod2TargetPosition <= 0 || rod2TargetPosition >= 1 {
            rod2Direction *= -1
        }
    }
    
    private func updateScore() {
        let curTime = CACurrentMediaTime()
       
        guard curTime - lastScoreTime >= 1.5 else { return }

        let needleAngle = needleNode.zRotation
        let maxDeflection = (2.0 * .pi / 3)
        let bonusRange    = 1.0 * .pi / 12

        guard abs(needleAngle) < maxDeflection else {
            lastScoreTime = curTime
            return
        }
        let points = abs(needleAngle) <= bonusRange ? 5 : 1

        score += CGFloat(points)
        scoreLabel.text = "Score: \(Int(score))"
        lastScoreTime = curTime
    }
    
    private func selectMode() {
        let modes = ["default","surge","coolant"]
        currentMode = modes.randomElement()!

        switch currentMode {
        case "default":
            startMode()
            
        case "surge":
            preFlash(textNode: surgeText, bgNode: surgeBG)
            
        case "coolant":
            preFlash(textNode: coolantText, bgNode: coolantBG)
            
        default:
            startMode()
        }
    }
    
    private func preFlash(textNode: SKSpriteNode, bgNode: SKSpriteNode) {

      let fadeIn  = SKAction.fadeIn(withDuration: 0.5)
      let fadeOut = SKAction.fadeOut(withDuration: 0.5)

      let textSeq = SKAction.sequence([
        fadeIn,
        .wait(forDuration: 5.0),
        fadeOut
      ])


      let bgSeq = SKAction.repeat(
        SKAction.sequence([fadeIn, fadeOut]),
        count: 5
      )
      textNode.run(textSeq)
      bgNode.run(bgSeq) { [weak self] in
        self?.startMode()
      }
    }
    
    private func startMode() {
        modeStartTime = CACurrentMediaTime()
        applyMode()
        
        removeAction(forKey:"modeTimer")
        removeAction(forKey:"modeTransition")
        
        // update mode timer every sec
        let timerAction = SKAction.repeat(
        .sequence([ .run { [weak self] in self?.updateTimer()},
                    .wait(forDuration:1.0) ]),
        count: Int(modeDuration))
        run(timerAction, withKey:"modeTimer")
        
        // run mode select every 10 sec
        let transition = SKAction.sequence([
            .wait(forDuration: modeDuration),
            .run { [weak self] in self?.endMode()}])
        run(transition, withKey:"modeTransition")
    }
    
    private func applyMode() {
        modeLabel.alpha = 0
        timerLabel.alpha = 0
        flipRodMovement = false
        
        switch currentMode {
        case "default":
            heatGenRate = defaultHeatGenRate
            coolingRate  = defaultCoolingRate
            timerLabel.alpha = 0
            
            break
        case "surge":
            modeLabel.text = "Surge"
            modeLabel.alpha = 1
            flipRodMovement = true
            timerLabel.alpha = 1
        case "coolant":
            modeLabel.text = "Coolant Leak"
            modeLabel.alpha = 1
            timerLabel.alpha = 1
            heatGenRate *= 1.5
            coolingRate *= 1.5
            break
        default:
            modeLabel.alpha = 0
            timerLabel.alpha = 0
            flipRodMovement = false
            heatGenRate = defaultHeatGenRate
            coolingRate  = defaultCoolingRate
        }

        
    }
    
    private func updateTimer() {
        let elapsed = CACurrentMediaTime() - modeStartTime
        let remaining = max(0, modeDuration - elapsed)
        timerLabel.text = "\(Int(remaining))s"
    }
    
    private func endMode() {
        heatGenRate = defaultHeatGenRate
        coolingRate  = defaultCoolingRate
        flipRodMovement = false
        timerLabel.alpha = 0
        
        selectMode()
    }
    


}
