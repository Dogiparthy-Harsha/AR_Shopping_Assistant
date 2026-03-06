import Foundation
import Combine
import Speech
import AVFoundation

// MARK: - Voice Command Types

enum VoiceCommandType {
    case wake       // "Hey Cart"
    case capture    // "I want this"
    case general    // Any other speech while active
}

struct VoiceCommand {
    let type: VoiceCommandType
    let text: String
    let timestamp: Date
}

// MARK: - Voice Command Manager

@MainActor
class VoiceCommandManager: ObservableObject {
    
    @Published var isListening = false
    @Published var appActive = false
    @Published var transcript = ""
    @Published var lastCommand: VoiceCommand?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var debounceTask: Task<Void, Never>?
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Wake words (fuzzy matches for various misrecognitions)
    private let wakeWords = [
        "hey assistant", "hey resistent", "hi assistant", "a assistant",
        "hey assess them", "hey assist", "hey system", "play assistant",
        "a system", "pay assistant", "gay assistant", "bay assistant"
    ]
    
    // Capture commands
    private let captureCommands = [
        "i want this", "check this item", "check this out",
        "what is this", "i want this item", "i want that"
    ]
    
    // MARK: - Initialization
    
    init() {
        // Don't request permissions in init — defer to avoid XPC crash
        print(">>> VoiceCommandManager init")
        // Permissions will be requested after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            self.requestPermissions()
        }
    }
    
    // MARK: - Permissions
    
    func requestPermissions() {
        // Check current status first
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        print(">>> Current speech auth status: \(currentStatus.rawValue) (0=notDetermined, 1=denied, 2=restricted, 3=authorized)")
        
        if currentStatus == .authorized {
            authorizationStatus = .authorized
            print(">>> Speech recognition already authorized")
            return
        }
        
        // Request microphone permission first via AVAudioSession
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] micGranted in
            Task { @MainActor in
                if micGranted {
                    print(">>> Microphone permission granted ✓")
                } else {
                    print(">>> Microphone permission DENIED — go to Settings > Privacy > Microphone")
                }
                
                // Then request speech recognition permission
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    Task { @MainActor in
                        self?.authorizationStatus = status
                        switch status {
                        case .authorized:
                            print(">>> Speech recognition authorized ✓")
                        case .denied:
                            print(">>> Speech recognition DENIED — go to Settings > Privacy > Speech Recognition")
                        case .restricted:
                            print(">>> Speech recognition RESTRICTED on this device")
                        case .notDetermined:
                            print(">>> Speech recognition still not determined")
                        @unknown default:
                            print(">>> Speech recognition unknown status: \(status.rawValue)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Start / Stop Listening
    
    func startListening() {
        guard authorizationStatus == .authorized else {
            print(">>> Speech recognition not authorized (status: \(authorizationStatus.rawValue)), requesting again...")
            requestPermissions()
            return
        }
        
        // Stop any existing recognition
        stopListening()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            #if targetEnvironment(simulator)
            // The iOS Simulator's audio engine (CoreAudio HAL) is often broken 
            // and can deadlock, return 0 Hz, or crash (SIGABRT) on initialization.
            print(">>> [Simulator] Attempting safe audio initialization...")
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.outputFormat(forBus: 0)
            
            // If the simulator returns an invalid format (0 Hz), we gracefully bail out 
            // instead of crashing or attempting workarounds that trigger deadlocks.
            guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
                print(">>> [Simulator] Audio driver failed to initialize (format is 0 Hz).")
                print(">>> [Simulator] Voice commands disabled to prevent crash.")
                isListening = false
                return
            }
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            #else
            // PHYSICAL DEVICE PATH: Full high-quality setup
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.outputFormat(forBus: 0)
            print(">>> [Device] Audio input native format: \(nativeFormat.sampleRate) Hz, \(nativeFormat.channelCount) ch")
            
            // On a real device, if the format is somehow 0 Hz, we can construct a fallback
            let recordingFormat: AVAudioFormat
            if nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 {
                recordingFormat = nativeFormat
            } else {
                let sampleRate = audioSession.sampleRate > 0 ? audioSession.sampleRate : 48000.0
                let channels = nativeFormat.channelCount > 0 ? nativeFormat.channelCount : 1
                recordingFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) ?? nativeFormat
            }
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            #endif
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            print(">>> Voice recognition started")
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let result = result {
                        let text = result.bestTranscription.formattedString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        self.transcript = text
                        
                        // Check for wake/capture instantly on partial results (fast reaction)
                        let isWakeWord = self.wakeWords.contains { text.contains($0) }
                        let isCaptureCommand = self.captureCommands.contains { text.contains($0) }
                        
                        self.debounceTask?.cancel()
                        
                        if isWakeWord || isCaptureCommand {
                            // Trigger immediately — don't wait for isFinal
                            let _ = self.processCommand(text)
                            self.restartListening()
                        } else if result.isFinal {
                            // General speech (answers/follow-up) — wait for the FULL sentence
                            // before sending to the API so we don't send half-words
                            let _ = self.processCommand(text)
                            self.restartListening()
                        } else if self.appActive && text.count > 2 {
                            // For general speech, iOS often fails to trigger isFinal.
                            // We use a debounce timer instead to detect when the user stopped speaking.
                            self.debounceTask = Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                                if !Task.isCancelled {
                                    let _ = self.processCommand(text)
                                    self.restartListening()
                                }
                            }
                        }
                        // else: still speaking, keep accumulating words
                    }
                    
                    if let error = error {
                        let errStr = error.localizedDescription
                        // "No speech detected" is normal when the user pauses — not an error
                        if !errStr.contains("No speech") {
                            print(">>> Speech recognition error: \(errStr)")
                        }
                        self.restartListening()
                    }
                }
            }
            
        } catch {
            print(">>> Audio engine error: \(error.localizedDescription)")
            isListening = false
        }
    }
    
    func stopListening() {
        debounceTask?.cancel()
        debounceTask = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    private func restartListening() {
        stopListening()
        // Brief delay before restarting
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if !synthesizer.isSpeaking {
                startListening()
            }
        }
    }
    
    // MARK: - Debug / Simulator Testing
    
    /// Programmatically fires a command — use in the simulator when mic is unavailable
    func simulateCommand(_ type: VoiceCommandType) {
        print(">>> [DEBUG] Simulating command: \(type)")
        switch type {
        case .wake:
            appActive = true
            lastCommand = VoiceCommand(type: .wake, text: "hey assistant [simulated]", timestamp: Date())
        case .capture:
            lastCommand = VoiceCommand(type: .capture, text: "i want this [simulated]", timestamp: Date())
        case .general:
            lastCommand = VoiceCommand(type: .general, text: "tell me more [simulated]", timestamp: Date())
        }
    }
    
    // MARK: - Command Processing
    
    private func processCommand(_ command: String) -> Bool {
        // Only log if it's substantial to avoid spam
        if command.count > 3 {
            print(">>> Heard: \(command)")
        }
        
        let isWakeWord = wakeWords.contains { command.contains($0) }
        let isCaptureCommand = captureCommands.contains { command.contains($0) }
        
        if isWakeWord {
            print(">>> WAKE WORD DETECTED")
            appActive = true
            lastCommand = VoiceCommand(type: .wake, text: command, timestamp: Date())
            return true
        } else if isCaptureCommand {
            print(">>> CAPTURE COMMAND DETECTED")
            lastCommand = VoiceCommand(type: .capture, text: command, timestamp: Date())
            return true
        } else if appActive && command.count > 2 {
            // General speech doesn't restart the listener immediately
            // so they can keep talking
            lastCommand = VoiceCommand(type: .general, text: command, timestamp: Date())
            return false
        }
        return false
    }
    
    // MARK: - Text to Speech
    
    func speak(_ text: String) {
        print(">>> SPEAKING: \(text)")
        
        // Stop listening while speaking to avoid feedback
        stopListening()
        
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        synthesizer.speak(utterance)
        
        // Resume listening after speech ends
        Task {
            // Wait for speech to finish
            while synthesizer.isSpeaking {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            startListening()
        }
    }
    
    // MARK: - Deactivate
    
    func deactivate() {
        appActive = false
        stopListening()
    }
}
