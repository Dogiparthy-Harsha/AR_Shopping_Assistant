// Vision API Interface for AR Shopping Assistant
// Connects to version_1 backend on port 8000

const API_BASE_URL = 'http://localhost:8000';

let authToken = null;
let conversationHistory = [];

/**
 * Register or login a guest user and get an auth token
 */
const ensureAuth = async () => {
    if (authToken) return authToken;

    const guestUser = {
        username: 'ar_guest_' + Math.random().toString(36).substring(7),
        password: 'ArGuest2026!Secure'
    };

    try {
        // Try to register
        const regRes = await fetch(`${API_BASE_URL}/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(guestUser),
        });

        if (regRes.ok) {
            const data = await regRes.json();
            authToken = data.access_token;
            console.log(">>> Auth: Registered guest user");
            return authToken;
        }
    } catch (error) {
        console.error("Auth registration error:", error);
    }

    throw new Error("Failed to authenticate with backend");
};

/**
 * Capture frame from webcam video stream
 * @param {HTMLVideoElement} videoElement
 * @returns {string} base64 encoded image (JPEG, without data URI prefix)
 */
export const captureFrame = (videoElement) => {
    if (!videoElement || videoElement.videoWidth === 0) {
        console.error(">>> captureFrame: video not ready", {
            exists: !!videoElement,
            width: videoElement?.videoWidth,
            height: videoElement?.videoHeight,
            readyState: videoElement?.readyState
        });
        return null;
    }

    const canvas = document.createElement('canvas');
    canvas.width = videoElement.videoWidth;
    canvas.height = videoElement.videoHeight;

    const ctx = canvas.getContext('2d');
    ctx.translate(canvas.width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);

    // Return base64 WITHOUT data URI prefix — backend expects raw base64
    // and prepends "data:image/jpeg;base64," itself (see api_mcp.py line 396)
    const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
    const base64 = dataUrl.split(',')[1];

    console.log(`>>> captureFrame: captured ${canvas.width}x${canvas.height}, base64 length: ${base64.length}`);
    return base64;
};

/**
 * Send chat message (and optional image) to the backend
 * @param {string} sessionId Unique UUID (unused by backend, kept for future)
 * @param {string} message The speech transcript
 * @param {string} [imageData] Base64 image data (without data URI prefix)
 */
export const sendMessage = async (sessionId, message, imageData = null) => {
    try {
        const token = await ensureAuth();

        const payload = {
            message: message,
            history: conversationHistory,
            conversation_id: null,  // Let backend create/manage
        };

        // Attach image_data if present (raw base64, no prefix)
        if (imageData) {
            payload.image_data = imageData;
        }

        console.log(">>> sendMessage: calling /chat with payload keys:", Object.keys(payload));
        console.log(">>> sendMessage: message:", message);
        console.log(">>> sendMessage: has image:", !!imageData);

        const response = await fetch(`${API_BASE_URL}/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`,
            },
            body: JSON.stringify(payload),
        });

        if (!response.ok) {
            const errText = await response.text();
            console.error(`>>> sendMessage: API error ${response.status}:`, errText);
            throw new Error(`API error! status: ${response.status} - ${errText}`);
        }

        const data = await response.json();
        console.log(">>> sendMessage: got response:", data);

        // Update conversation history for future calls
        if (data.history) {
            conversationHistory = data.history;
        }

        // Normalize response format for App.jsx
        // Backend returns: { type, message, conversation_id, history, results, a2ui_content }
        return {
            response: data.message,
            ui: data.a2ui_content || null,
            results: data.results || null,
            conversationId: data.conversation_id,
        };

    } catch (error) {
        console.error(">>> sendMessage: Vision API Error:", error);
        throw error;
    }
};
