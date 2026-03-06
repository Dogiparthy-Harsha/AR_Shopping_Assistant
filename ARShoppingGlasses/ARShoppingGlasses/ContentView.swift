//
//  ContentView.swift
//  ARShoppingGlasses
//
//  Created by Harsha Dogiparthy
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var glassesManager: GlassesManager
    @EnvironmentObject var voiceManager: VoiceCommandManager
    @EnvironmentObject var apiService: APIService
    
    @State private var showApp = false
    
    var body: some View {
        ZStack {
            if showApp && glassesManager.isConnected {
                // Main camera + voice experience
                CameraStreamView(
                    glassesManager: glassesManager,
                    voiceManager: voiceManager,
                    apiService: apiService
                )
                .transition(.opacity)
            } else {
                // Welcome / Connect screen
                connectView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showApp)
        .animation(.easeInOut(duration: 0.4), value: glassesManager.isConnected)
    }
    
    // MARK: - Connect View
    
    private var connectView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.12),
                    Color(red: 0.08, green: 0.04, blue: 0.18),
                    Color(red: 0.04, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(.cyan.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -100)
            
            Circle()
                .fill(.purple.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 100, y: 200)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo area
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("CartLog AI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("AR Shopping with Meta Glasses")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Status & connection
                VStack(spacing: 20) {
                    // Connection status
                    connectionStatusCard
                    
                    // Connect button
                    Button {
                        if glassesManager.isConnected {
                            withAnimation { showApp = true }
                        } else {
                            glassesManager.connect()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: glassesManager.isConnected
                                  ? "camera.fill" : "link")
                            Text(glassesManager.isConnected
                                 ? "Start Shopping" : "Connect Glasses")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .cyan.opacity(0.3), radius: 20)
                    }
                    
                    #if DEBUG
                    // Mock mode button (debug only)
                    if !glassesManager.isConnected {
                        Button {
                            glassesManager.setupMockDevice()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "hammer.fill")
                                    .font(.caption)
                                Text("Use Mock Device (Testing)")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .shadow(color: statusColor, radius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(glassesManager.connectionDisplayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Text(statusSubtext)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            if glassesManager.isMockMode {
                Text("MOCK")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch glassesManager.connectionState {
        case .disconnected: return .red
        case .connecting: return .yellow
        case .connected, .streaming: return .green
        case .error: return .red
        }
    }
    
    private var statusSubtext: String {
        switch glassesManager.connectionState {
        case .disconnected: return "Tap Connect to pair your Meta glasses"
        case .connecting: return "Looking for nearby glasses..."
        case .connected: return "Ready to start shopping"
        case .streaming: return "Camera feed active"
        case .error: return glassesManager.errorMessage
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlassesManager())
        .environmentObject(VoiceCommandManager())
        .environmentObject(APIService.shared)
}
