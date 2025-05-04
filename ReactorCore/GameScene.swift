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

    
    // pressure needle
    private var reactorTemp: CGFloat = 0.5
    private var needleCurAngle: CGFloat = 0.0
    private let heatGenRate: CGFloat = 0.005
    private let coolingRate: CGFloat = 0.004
    private let tempDriftRate: CGFloat = 0.0008
    private let needleSmooth: CGFloat = 0.5
    
    
    private var previousKnobAngle: CGFloat = 0
    
    private var rod1Direction: CGFloat = 1.0
    private var rod2Direction: CGFloat = -1.0
    private let rodDriftSpeed: CGFloat = 0.005
    
    // main scene
    override func didMove(to view: SKView) {
        backgroundColor = .black
        guard
            let knob = childNode(withName: "knobNode") as? SKSpriteNode,
            let r1 = childNode(withName: "rod1") as? SKSpriteNode,
            let r2 = childNode(withName: "rod2") as? SKSpriteNode,
            let r3 = childNode(withName: "rod3") as? SKSpriteNode,
            let needle = childNode(withName: "needle") as? SKSpriteNode
        else {
            print("Error: missing nodes")
            return
        }
        knobNode = knob
        rod1 = r1
        rod2 = r2
        rod3 = r3
        needleNode = needle
        
        haptic.prepare()
        lastTickAngle = knobNode.zRotation
        updateRodPositions()
        
        let updateAction = SKAction.customAction(withDuration: 1.0/60.0) { [weak self] _, _ in
            self?.updateGameState()
        }
        // run main logic
        run(SKAction.repeatForever(updateAction))
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
        updateRodTargetPositions(angleDiff: angleDiff)

        lastKnobAngle = angle
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isKnobTouched = false
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
    }
    
    // rod movement animation
    private func updateRodPositions() {
        rod1Position += (rod1TargetPosition - rod1Position) * rodMoveSpeed
        rod2Position += (rod2TargetPosition - rod2Position) * rodMoveSpeed * 0.8
        rod3Position += (rod3TargetPosition - rod3Position) * rodMoveSpeed * 1.2
        
        rod1?.position.y = rodMinY + (rodMaxY - rodMinY) * rod1Position
        rod2?.position.y = rodMinY + (rodMaxY - rodMinY) * rod2Position
        rod3?.position.y = rodMinY + (rodMaxY - rodMinY) * rod3Position
    }
    
    // rod movement based on knob rotation
    private func updateRodTargetPositions(angleDiff: CGFloat) {
        let scaleFactor: CGFloat = 0.08
        
        if angleDiff > 0 {
            rod1TargetPosition = max(0.0, rod1TargetPosition - abs(angleDiff) * scaleFactor)
            rod2TargetPosition = max(0.0, rod2TargetPosition - abs(angleDiff) * scaleFactor * 0.8)
            rod3TargetPosition = max(0.0, rod3TargetPosition - abs(angleDiff) * scaleFactor * 1.2)
        } else {
            rod1TargetPosition = min(1.0, rod1TargetPosition + abs(angleDiff) * scaleFactor)
            rod2TargetPosition = min(1.0, rod2TargetPosition + abs(angleDiff) * scaleFactor * 0.8)
            rod3TargetPosition = min(1.0, rod3TargetPosition + abs(angleDiff) * scaleFactor * 1.2)
        }
    }
    
    // triggers haptic
    private func checkForHaptic(newAngle: CGFloat) {
        let delta = calculateAngleDiff(from: lastTickAngle, to: newAngle)

        if abs(delta) >= tickStep {
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
}
