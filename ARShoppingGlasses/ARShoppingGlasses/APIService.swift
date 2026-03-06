import Foundation
import Combine

// MARK: - Response Models

struct ChatResponse: Codable {
    let type: String
    let message: String
    let conversationId: Int?
    let history: [[String: AnyCodableValue]]?
    let results: SearchResults?
    
    enum CodingKeys: String, CodingKey {
        case type, message, history, results
        case conversationId = "conversation_id"
    }
}

struct SearchResults: Codable {
    let ebay: [ProductItem]?
    let amazon: [ProductItem]?
}

struct ProductItem: Codable, Identifiable {
    var id: String { itemId ?? UUID().uuidString }
    var itemId: String?
    var title: String?
    var price: String?
    var imageUrl: String?
    var itemWebUrl: String?
    var condition: String?
    var source: String?
    
    enum CodingKeys: String, CodingKey {
        case title, price, condition, source
        
        // These keys might not exist in every agent's output, so we map them safely
        // eBay might send item_id, Amazon might not. Both send 'url'
        case itemId = "item_id"
        case imageUrl = "image_url"
        case itemWebUrl = "url"      // <-- The backend sends "url", not "item_web_url"
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - AnyCodableValue (for flexible history decoding)

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - API Service

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    // Use Mac's local IP so iPhone can reach the backend over WiFi
    // Simulator: localhost works fine | Real device: needs local IP
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "http://192.168.1.233:8000"
    #endif
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var lastError: String?
    
    private var authToken: String?
    private var conversationHistory: [Any] = []
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    
    // MARK: - Authentication
    
    /// Register a guest user and get JWT token
    func ensureAuth() async throws -> String {
        if let token = authToken {
            return token
        }
        
        let guestUser: [String: String] = [
            "username": "meta_glasses_\(Int.random(in: 10000...99999))",
            "password": "MetaGuest2026!Secure"
        ]
        
        guard let url = URL(string: "\(baseURL)/register") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: guestUser)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.authFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        authToken = authResponse.accessToken
        isAuthenticated = true
        print(">>> Auth: Registered guest user for Meta Glasses")
        return authResponse.accessToken
    }
    
    // MARK: - Chat / Vision API
    
    /// Send a chat message with optional image to the backend
    func sendMessage(_ message: String, imageData: String? = nil) async throws -> ChatResponse {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        let token = try await ensureAuth()
        
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw APIError.invalidURL
        }
        
        var payload: [String: Any] = [
            "message": message,
            "history": conversationHistory
        ]
        
        if let imageData = imageData {
            payload["image_data"] = imageData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print(">>> sendMessage: calling /chat | message: \(message) | has image: \(imageData != nil)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(errText)
        }
        
        var chatResponse: ChatResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            print(">>> JSON DECODING ERROR: \(error)")
            if let rawString = String(data: data, encoding: .utf8) {
                print(">>> RAW JSON: \(rawString.prefix(500))...")
            }
            throw APIError.serverError("Failed to parse response: \(error.localizedDescription)")
        }
        
        // Update conversation history
        if let history = chatResponse.history {
            conversationHistory = history.map { dict in
                var result: [String: Any] = [:]
                for (key, value) in dict {
                    switch value {
                    case .string(let s): result[key] = s
                    case .int(let i): result[key] = i
                    case .double(let d): result[key] = d
                    case .bool(let b): result[key] = b
                    case .null: result[key] = NSNull()
                    }
                }
                return result
            }
        }
        
        print(">>> sendMessage: got response type: \(chatResponse.type)")
        return chatResponse
    }
    
    // MARK: - Reset
    
    func resetConversation() {
        conversationHistory = []
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case authFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .authFailed: return "Failed to authenticate with backend"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}
