import Foundation
import Combine
import UIKit
import MWDATCore
import MWDATCamera
#if DEBUG
import MWDATMockDevice
#endif

// MARK: - Connection State

// Simple enum without associated values to avoid Swift runtime witness table issues
enum GlassesConnectionState: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
    case streaming = 3
    case error = 4
}

// MARK: - Glasses Manager

class GlassesManager: ObservableObject {
    
    @Published var connectionState: GlassesConnectionState = .disconnected
    @Published var errorMessage: String = ""
    @Published var latestFrameImage: UIImage?
    @Published var latestFrameBase64: String?
    @Published var isMockMode = false
    
    private var streamSession: StreamSession?
    private var frameListenerToken: (any AnyListenerToken)?
    private var stateListenerToken: (any AnyListenerToken)?
    
    #if DEBUG
    private var mockDevice: (any MockRaybanMeta)?
    #endif
    
    // Computed helpers
    var isConnected: Bool {
        connectionState == .connected || connectionState == .streaming
    }
    
    var connectionDisplayText: String {
        switch connectionState {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming: return "Live Streaming"
        case .error: return "Error: \(errorMessage)"
        }
    }
    
    // MARK: - Initialization
    
    init() {
        do {
            try Wearables.configure()
            print(">>> Meta Wearables SDK configured")
        } catch let error as WearablesError where error == .alreadyConfigured {
            print(">>> Meta Wearables SDK already configured (OK)")
        } catch {
            print(">>> Meta Wearables SDK configure error: \(error)")
        }
    }
    
    // MARK: - Mock Device Setup (for testing without glasses)
    
    #if DEBUG
    @MainActor
    func setupMockDevice() {
        isMockMode = true
        print(">>> Setting up Mock Device Kit for testing")
        
        let device = MockDeviceKit.shared.pairRaybanMeta()
        mockDevice = device
        
        device.powerOn()
        device.don()
        device.unfold()
        
        connectionState = .connected
        print(">>> Mock Ray-Ban Meta paired, powered on, and ready")
    }
    
    @MainActor
    func teardownMockDevice() {
        if let device = mockDevice {
            MockDeviceKit.shared.unpairDevice(device)
        }
        mockDevice = nil
        connectionState = .disconnected
        isMockMode = false
        print(">>> Mock device unpaired")
    }
    #endif
    
    // MARK: - Connection (Real Device)
    
    func connect() {
        connectionState = .connecting
        print(">>> Attempting to connect to glasses...")
        
        Task { @MainActor in
            do {
                try await Wearables.shared.startRegistration()
                self.connectionState = .connected
                print(">>> Registration successful, glasses connected")
            } catch {
                self.connectionState = .error
                self.errorMessage = error.localizedDescription
                print(">>> Connection failed: \(error)")
            }
        }
    }
    
    func disconnect() {
        Task {
            await stopStreaming()
        }
        connectionState = .disconnected
        
        #if DEBUG
        Task { @MainActor in
            if self.isMockMode {
                self.teardownMockDevice()
            }
        }
        #endif
        
        print(">>> Glasses disconnected")
    }
    
    // MARK: - Camera Streaming
    
    @MainActor
    func startStreaming() {
        guard isConnected else {
            print(">>> Cannot stream: not connected")
            return
        }
        
        print(">>> Starting camera stream...")
        
        let deviceSelector = AutoDeviceSelector(wearables: Wearables.shared)
        let session = StreamSession(deviceSelector: deviceSelector)
        streamSession = session
        
        frameListenerToken = session.videoFramePublisher.listen { [weak self] frame in
            Task { @MainActor in
                guard let self = self else { return }
                if let uiImage = frame.makeUIImage() {
                    self.latestFrameImage = uiImage
                    if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                        self.latestFrameBase64 = jpegData.base64EncodedString()
                    }
                }
            }
        }
        
        stateListenerToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                switch state {
                case .streaming:
                    self?.connectionState = .streaming
                    print(">>> Stream state: streaming")
                case .stopped:
                    print(">>> Stream state: stopped")
                case .waitingForDevice:
                    print(">>> Stream state: waiting for device")
                case .paused:
                    print(">>> Stream state: paused")
                default:
                    print(">>> Stream state: \(state)")
                }
            }
        }
        
        Task {
            await session.start()
        }
    }
    
    func stopStreaming() async {
        await frameListenerToken?.cancel()
        await stateListenerToken?.cancel()
        frameListenerToken = nil
        stateListenerToken = nil
        
        await streamSession?.stop()
        streamSession = nil
        
        if connectionState == .streaming {
            connectionState = .connected
        }
        print(">>> Camera stream stopped")
    }
    
    // MARK: - Photo Capture
    
    @MainActor
    func captureFrame() -> String? {
        // First: try real glasses camera frame
        if let base64 = latestFrameBase64 {
            print(">>> Frame captured from glasses, base64 length: \(base64.count)")
            return base64
        }
        
        // Second: try to trigger a photo capture (real glasses)
        streamSession?.capturePhoto(format: .jpeg)
        
        // Fallback: use bundled test product image (mock mode / simulator testing)
        if let testImage = UIImage(named: "TestProduct"),
           let jpegData = testImage.jpegData(compressionQuality: 0.8) {
            let base64 = jpegData.base64EncodedString()
            print(">>> Using bundled test product image (mock mode), base64 length: \(base64.count)")
            return base64
        }
        
        print(">>> No frame available to capture")
        return nil
    }
}
