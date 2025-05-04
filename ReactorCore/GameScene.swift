//
//  GameScene.swift
//  ReactorCore
//
//  Created by Deepinder on 2025-05-03.
//

import SpriteKit
import UIKit

class GameScene: SKScene {
    
    private var knobNode: SKSpriteNode!
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastTickAngle: CGFloat = 0
    private let tickStep: CGFloat = 0.3
    private let knobTouchRadius: CGFloat = 350
    private var isKnobTouched: Bool = false
    
    private var rod1: SKSpriteNode!
    private var rod2: SKSpriteNode!
    private var rod3: SKSpriteNode!
    private let rodMinY: CGFloat = -100
    private let rodMaxY: CGFloat = 150
    private var rodPosition: CGFloat = 0.0
    
    private var needleNode: SKSpriteNode!
    private var reactorTemp: CGFloat = 0.5
    private var needleCurAngle: CGFloat = 0.0
    

    private let heatGenRate: CGFloat = 0.01
    private let coolingRate: CGFloat = 0.008
    private let tempDriftRate: CGFloat = 0.0016
    private let needleSmooth: CGFloat = 0.8    
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        knobNode = childNode(withName: "knobNode") as? SKSpriteNode
        if knobNode == nil {
            print("error: missing knobNode")
            return
        }
        
        rod1 = childNode(withName: "rod1") as? SKSpriteNode
        rod2 = childNode(withName: "rod2") as? SKSpriteNode
        rod3 = childNode(withName: "rod3") as? SKSpriteNode
        
        if rod1 == nil || rod2 == nil || rod3 == nil {
            print("error: missing rodNodes")
            return
        }
        
        needleNode = childNode(withName: "needle") as? SKSpriteNode
        if needleNode == nil {
            print("error: missing needleNode")
            return
        }
        
        haptic.prepare()
        lastTickAngle = knobNode.zRotation
        updateRodPositions()
        
        let updateAction = SKAction.customAction(withDuration: 1.0/60.0) { [weak self] _, _ in
            self?.updateGameState()
        }
        run(SKAction.repeatForever(updateAction))
    }
    
    private func updateGameState() {
   
        let heatGen = rodPosition * heatGenRate
        let cooling = (1.0 - rodPosition) * coolingRate
        
        let time = CGFloat(CACurrentMediaTime())
        // Increased drift amplitude, decreased frequency for slower swings
        let drift = sin(time * 0.2) * tempDriftRate + CGFloat.random(in: -0.002...0.002)
        
        // Update reactor temperature
        reactorTemp += heatGen - cooling + drift
        reactorTemp = max(0.0, min(1.0, reactorTemp))
        
    
        let needleRange: CGFloat = 2.0 * .pi / 3.0
        let targetRotation = needleRange * (reactorTemp * 2 - 1)
        let rotationDiff = targetRotation - needleCurAngle
        
        needleCurAngle += rotationDiff * needleSmooth
        needleNode.zRotation = needleCurAngle
        
    }
    
    private func updateRodPositions() {
        let yPos = rodMinY + (rodMaxY - rodMinY) * rodPosition
        
        rod1?.position.y = yPos
        rod2?.position.y = yPos
        rod3?.position.y = yPos
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let distance = distanceBetween(p1: location, p2: knobNode.position)
        if distance <= knobTouchRadius {
            isKnobTouched = true
        }
    }
    
    private func distanceBetween(p1: CGPoint, p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isKnobTouched, let touch = touches.first else { return }
        
        let touchLocation = touch.location(in: self)
        let angle = angleBetween(knobCenter: knobNode.position, to: touchLocation)
        
        knobNode.zRotation = angle
        checkForHaptic(newAngle: angle)
        
        let angleDiff = calculateAngleDiff(from: lastTickAngle, to: angle)
        
        updateRod(angleDiff: angleDiff)
        updateRodPositions()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isKnobTouched = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isKnobTouched = false
    }
    
    private func angleBetween(knobCenter: CGPoint, to touchPoint: CGPoint) -> CGFloat {
        let dx = touchPoint.x - knobCenter.x
        let dy = touchPoint.y - knobCenter.y
        
        return atan2(dy, dx) - CGFloat.pi / 2
    }
    
    private func checkForHaptic(newAngle: CGFloat) {
        let delta = calculateAngleDiff(from: lastTickAngle, to: newAngle)

        if abs(delta) >= tickStep {
            haptic.impactOccurred()
            haptic.prepare()
            lastTickAngle = newAngle
        }
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
    
    private func updateRod(angleDiff: CGFloat) {
        let scaleFactor: CGFloat = 0.1
        
        if angleDiff > 0 {
            rodPosition = max(0.0, rodPosition - abs(angleDiff) * scaleFactor)
        } else if angleDiff < 0 {
            rodPosition = min(1.0, rodPosition + abs(angleDiff) * scaleFactor)
        }
    }
}
