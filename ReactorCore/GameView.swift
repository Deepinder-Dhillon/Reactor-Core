//
//  GameView.swift
//  ReactorCore
//
//  Created by Deepinder on 2025-05-03.
//


import SwiftUI
import SpriteKit

struct GameView: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)
        skView.ignoresSiblingOrder = true
    

        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            fatalError("Couldn’t load GameScene.sks")
        }

        let designSize = CGSize(width: 1080, height: 1920)
        scene.size = designSize
        

        scene.scaleMode = .aspectFill

        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
       
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
                        
    }
}

