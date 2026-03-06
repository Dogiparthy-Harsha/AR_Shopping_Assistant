//
//  ARShoppingGlassesApp.swift
//  ARShoppingGlasses
//
//  Created by Harsha Dogiparthy
//

import SwiftUI

@main
struct ARShoppingGlassesApp: App {
    
    @StateObject private var glassesManager = GlassesManager()
    @StateObject private var voiceManager = VoiceCommandManager()
    @StateObject private var apiService = APIService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(glassesManager)
                .environmentObject(voiceManager)
                .environmentObject(apiService)
                .preferredColorScheme(.dark)
        }
    }
}
