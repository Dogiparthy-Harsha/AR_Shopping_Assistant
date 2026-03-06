import SwiftUI

// MARK: - Camera Stream View

struct CameraStreamView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var voiceManager: VoiceCommandManager
    @ObservedObject var apiService: APIService
    
    @State private var statusMessage = "Say \"Hey Assistant\" to wake"
    @State private var isProcessing = false
    @State private var showResults = false
    @State private var searchResults: SearchResults?
    @State private var aiMessage: String?
    @State private var pulseAnimation = false
    @State private var showDebugPanel = false
    
    var body: some View {
        ZStack {
            // Background - camera feed or placeholder
            cameraFeedLayer
            
            // Status overlay
            VStack {
                // Top bar - connection status
                topStatusBar
                
                Spacer()
                
                // AI message bar (floating glass message)
                if let message = aiMessage {
                    aiMessageBar(message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom bar - voice status & transcript
                bottomVoiceBar
            }
            .padding()
            
            // Loading overlay
            if isProcessing {
                loadingOverlay
            }
            
            // Results panels
            if showResults, let results = searchResults {
                ProductResultsView(results: results) {
                    withAnimation(.spring(response: 0.4)) {
                        showResults = false
                        searchResults = nil
                        aiMessage = nil
                        statusMessage = "Say \"Hey Assistant\" to wake"
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Simulator-only debug panel (since mic emulation is broken)
            #if targetEnvironment(simulator)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showDebugPanel.toggle() }) {
                        Image(systemName: "ladybug.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            
            if showDebugPanel {
                VStack(spacing: 12) {
                    Text("🐛 Simulator Test Controls")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Button("👋 Hey Assistant") {
                            voiceManager.simulateCommand(.wake)
                            showDebugPanel = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        
                        Button("📷 I want this") {
                            voiceManager.simulateCommand(.capture)
                            showDebugPanel = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .font(.callout)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.5), lineWidth: 1))
                .padding()
            }
            #endif
        }
        .onAppear {
            voiceManager.startListening()
        }
        .onChange(of: voiceManager.lastCommand?.timestamp) { _, _ in
            handleVoiceCommand()
        }
    }
    
    // MARK: - Camera Feed Layer
    
    private var cameraFeedLayer: some View {
        Group {
            if let uiImage = glassesManager.latestFrameImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                // Placeholder when no camera feed
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay {
                    VStack(spacing: 20) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(), value: pulseAnimation)
                        
                        if glassesManager.isMockMode {
                            Text("Mock Camera Mode")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                    .onAppear { pulseAnimation = true }
                }
            }
        }
    }
    
    // MARK: - Top Status Bar
    
    private var topStatusBar: some View {
        HStack {
            // Connection indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(glassesManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(glassesManager.connectionDisplayText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            Spacer()
            
            // Listening indicator
            if voiceManager.isListening {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Listening")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - AI Message Bar
    
    private func aiMessageBar(_ message: String) -> some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.cyan)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.1), radius: 20)
    }
    
    // MARK: - Bottom Voice Bar
    
    private var bottomVoiceBar: some View {
        VStack(spacing: 12) {
            // Transcript
            if !voiceManager.transcript.isEmpty {
                Text(voiceManager.transcript)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Status message
            Text(statusMessage)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    voiceManager.appActive
                                        ? Color.cyan.opacity(0.4)
                                        : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: voiceManager.appActive ? .cyan.opacity(0.2) : .clear, radius: 15)
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.cyan)
                
                Text("Analyzing...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - Voice Command Handler
    
    private func handleVoiceCommand() {
        guard let command = voiceManager.lastCommand else { return }
        
        switch command.type {
        case .wake:
            withAnimation(.spring(response: 0.4)) {
                statusMessage = "Listening... say \"I want this\""
                voiceManager.speak("Hi! Point at something and say I want this.")
            }
            
        case .capture:
            withAnimation(.spring(response: 0.4)) {
                statusMessage = "Capturing..."
                isProcessing = true
            }
            
            // Capture frame from glasses camera
            let frameBase64 = glassesManager.captureFrame()
            
            Task {
                do {
                    let response = try await apiService.sendMessage(
                        "I want this",
                        imageData: frameBase64
                    )
                    
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4)) {
                            isProcessing = false
                            
                            if let results = response.results {
                                searchResults = results
                                showResults = true
                                statusMessage = "Results found!"
                                voiceManager.speak("I found some results for you.")
                            } else {
                                aiMessage = response.message
                                statusMessage = "Answer the question..."
                                voiceManager.speak(response.message)
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        withAnimation {
                            isProcessing = false
                            aiMessage = "Error: \(error.localizedDescription)"
                            statusMessage = "Try again"
                        }
                    }
                }
            }
            
        case .general:
            guard voiceManager.appActive else { return }
            
            withAnimation(.spring(response: 0.4)) {
                isProcessing = true
                statusMessage = "Processing..."
            }
            
            Task {
                do {
                    let response = try await apiService.sendMessage(command.text)
                    
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4)) {
                            isProcessing = false
                            
                            if let results = response.results {
                                searchResults = results
                                showResults = true
                                statusMessage = "Results found!"
                                voiceManager.speak("Here are your results.")
                            } else {
                                aiMessage = response.message
                                statusMessage = "Listening..."
                                voiceManager.speak(response.message)
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        withAnimation {
                            isProcessing = false
                            aiMessage = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}
