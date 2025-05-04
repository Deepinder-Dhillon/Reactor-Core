//
//  ReactorCoreApp.swift
//  ReactorCore
//
//  Created by Deepinder on 2025-05-03.
//

import SwiftUI

@main
struct ReactorCoreApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}
