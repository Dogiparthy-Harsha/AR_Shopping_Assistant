import { useState, useRef, useEffect } from 'react';
import { v4 as uuidv4 } from 'uuid';
import HandTracker from './components/HandTracker';
import useVoiceCommands from './hooks/useVoiceCommands';
import { captureFrame, sendMessage } from './api/visionClaw';
import { Mic, MicOff, Loader, ExternalLink, Tag, AlertCircle } from 'lucide-react';
import './index.css';

/* ─── Product Card (Glassmorphism) ──────────────────────────── */
function ProductCard({ item, source }) {
  const title = item.title || 'Unknown Product';
  const price = item.price || 'N/A';
  const imgUrl = item.image_url || item.image;
  const url = item.url || '#';

  return (
    <div className="glass-card p-4">
      {/* Image well */}
      {imgUrl && (
        <div className="glass-img-well p-2 mb-3">
          <img
            src={imgUrl}
            alt={title}
            className="w-full h-32 object-contain rounded-xl"
          />
        </div>
      )}

      {/* Title — 2-line clamp */}
      <h3 className="text-[13px] font-semibold text-white/90 leading-snug line-clamp-2 mb-2 relative z-10">
        {title}
      </h3>

      {/* Price pill */}
      <div className="price-badge mb-3 relative z-10">
        <Tag size={12} className="opacity-70" />
        <span>{price}</span>
      </div>

      {/* CTA button */}
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        className="glass-btn flex items-center justify-center gap-2 w-full px-4 py-2 text-xs font-medium relative z-10"
      >
        View on {source}
        <ExternalLink size={11} className="opacity-60" />
      </a>
    </div>
  );
}

/* ─── Results Panels (eBay left, Amazon right) ──────────────── */
function ResultsPanels({ results }) {
  if (!results) return null;
  const ebay = results.ebay || [];
  const amazon = results.amazon || [];
  if (!ebay.length && !amazon.length) return null;

  return (
    <>
      {/* eBay — left column */}
      {ebay.length > 0 && (
        <div
          className="absolute flex flex-col pointer-events-none z-40"
          style={{
            top: '80px',
            bottom: '80px',
            left: '24px',
            width: '300px',
          }}
        >
          {/* Header chip */}
          <div
            className="glass-chip flex items-center pointer-events-auto shrink-0 anim-slide-right"
            style={{ padding: '8px 16px', marginBottom: '16px', gap: '8px' }}
          >
            <div className="w-5 h-5 rounded-md bg-blue-500/25 border border-blue-400/20 flex items-center justify-center text-blue-300 font-bold text-[10px]">e</div>
            <span className="text-sm font-semibold text-white/75 tracking-wide">eBay</span>
            <span className="ml-auto text-[10px] text-white/30 font-medium">{ebay.length} found</span>
          </div>

          {/* Scrollable card list */}
          <div
            className="flex-1 no-scrollbar"
            style={{ overflowY: 'auto', minHeight: 0 }}
          >
            <div className="flex flex-col anim-stagger" style={{ gap: '16px', paddingBottom: '16px' }}>
              {ebay.map((item, i) => (
                <div key={i} className="pointer-events-auto anim-slide-right">
                  <ProductCard item={item} source="eBay" />
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Amazon — right column */}
      {amazon.length > 0 && (
        <div
          className="absolute flex flex-col pointer-events-none z-40"
          style={{
            top: '80px',
            bottom: '80px',
            right: '24px',
            width: '300px',
          }}
        >
          {/* Header chip */}
          <div
            className="glass-chip flex items-center justify-end pointer-events-auto shrink-0 anim-slide-left"
            style={{ padding: '8px 16px', marginBottom: '16px', gap: '8px' }}
          >
            <span className="mr-auto text-[10px] text-white/30 font-medium">{amazon.length} found</span>
            <span className="text-sm font-semibold text-white/75 tracking-wide">Amazon</span>
            <div className="w-5 h-5 rounded-md bg-orange-500/25 border border-orange-400/20 flex items-center justify-center text-orange-300 font-bold text-[10px]">A</div>
          </div>

          {/* Scrollable card list */}
          <div
            className="flex-1 no-scrollbar"
            style={{ overflowY: 'auto', minHeight: 0 }}
          >
            <div className="flex flex-col anim-stagger" style={{ gap: '16px', paddingBottom: '16px' }}>
              {amazon.map((item, i) => (
                <div key={i} className="pointer-events-auto anim-slide-left">
                  <ProductCard item={item} source="Amazon" />
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </>
  );
}

/* ─── Loading Overlay ───────────────────────────────────────── */
function LoadingOverlay() {
  return (
    <div className="absolute inset-0 bg-black/95 flex flex-col items-center justify-center z-[200]">
      <Loader className="w-10 h-10 text-white/40 animate-spin mb-5" />
      <p className="text-sm font-medium text-white/50 tracking-[0.25em] uppercase">
        Initializing Vision Engine
      </p>
    </div>
  );
}

/* ─── Main App ──────────────────────────────────────────────── */
export default function App() {
  const [isTracking, setIsTracking] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [sessionId, setSessionId] = useState('');
  const [a2uiData, setA2uiData] = useState(null);
  const [rawResults, setRawResults] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [messages, setMessages] = useState([]);

  // Persistent LLM message (stays until user speaks next)
  const [llmMessage, setLlmMessage] = useState(null);
  // Status for transient feedback like "Capturing..." / "Error..."
  const [statusMsg, setStatusMsg] = useState(null);
  const [statusType, setStatusType] = useState('info'); // 'info' | 'error'

  const videoRef = useRef(null);
  const { isListening, transcript, appActive, lastCommand } = useVoiceCommands();

  /* ── Camera Init ── */
  useEffect(() => {
    setSessionId(uuidv4());
    navigator.mediaDevices.getUserMedia({
      video: { width: 1280, height: 720, facingMode: 'user' }
    }).then((stream) => {
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }
      setIsLoading(false);
    }).catch((err) => {
      console.error('Camera error:', err);
      setIsLoading(false);
    });
    return () => {
      if (videoRef.current?.srcObject) {
        videoRef.current.srcObject.getTracks().forEach(t => t.stop());
      }
    };
  }, []);

  /* ── Voice Command Handler ── */
  useEffect(() => {
    if (!lastCommand) return;

    const run = async () => {
      if (lastCommand.type === 'wake') {
        setLlmMessage(null);
        setStatusMsg('Awake! Point and say "I want this"');
        setStatusType('info');
        return;
      }

      if (isProcessing) return;
      setIsProcessing(true);
      setLlmMessage(null);
      setStatusType('info');

      if (lastCommand.type === 'capture') {
        setStatusMsg('Capturing image…');
        try {
          const imageData = captureFrame(videoRef.current);
          if (!imageData) console.error("Could not capture frame.");
          setStatusMsg('Analyzing…');
          setMessages(prev => [...prev, { role: 'user', content: lastCommand.text }]);
          const res = await sendMessage(sessionId, lastCommand.text, imageData);
          handleApiResponse(res);
        } catch (err) {
          console.error(err);
          setStatusMsg('Error analyzing image');
          setStatusType('error');
          setIsProcessing(false);
        }
      } else if (lastCommand.type === 'general') {
        setStatusMsg('Processing…');
        try {
          setMessages(prev => [...prev, { role: 'user', content: lastCommand.text }]);
          const res = await sendMessage(sessionId, lastCommand.text);
          handleApiResponse(res);
        } catch (err) {
          console.error(err);
          setStatusMsg('Error sending message');
          setStatusType('error');
          setIsProcessing(false);
        }
      }
    };
    run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lastCommand?.timestamp]);

  const handleApiResponse = (response) => {
    if (response?.response) {
      setMessages(prev => [...prev, { role: 'assistant', content: response.response }]);
      setLlmMessage(response.response);
      setStatusMsg(null);
    }
    if (response?.results) {
      console.log('>>> Raw results:', response.results);
      setRawResults(response.results);
    }
    if (response?.ui) setA2uiData(response.ui);
    setIsProcessing(false);
  };

  /* ── Render ── */
  return (
    <div className="relative w-screen h-screen overflow-hidden select-none text-white">
      {isLoading && <LoadingOverlay />}

      {/* ── Camera feed ── */}
      <video
        ref={videoRef}
        autoPlay playsInline muted
        className={`absolute inset-0 w-full h-full object-cover -scale-x-100 z-0 transition-all duration-1000 ${appActive ? 'brightness-[0.7]' : 'brightness-100'}`}
      />

      {/* ═══════════════════════════════════════════════════════
          TOP HUD — status pill + LLM message
          ═══════════════════════════════════════════════════════ */}
      <div className={`absolute top-0 left-0 w-full pt-5 px-6 z-50 flex flex-col items-center transition-all duration-600 ${appActive ? 'translate-y-0 opacity-100' : '-translate-y-12 opacity-0 pointer-events-none'}`}>

        {/* Status pill (processing / errors) */}
        {(isProcessing || statusMsg) && (
          <div className={`glass-pill flex items-center gap-3 px-5 py-2.5 mb-3 anim-drop ${statusType === 'error' ? 'glass-pill--error' : ''}`}>
            {isProcessing ? (
              <Loader className="w-4 h-4 text-white/50 animate-spin" />
            ) : statusType === 'error' ? (
              <AlertCircle className="w-4 h-4 text-red-400" />
            ) : isListening ? (
              <div className="relative">
                <Mic className="w-4 h-4 text-green-400" />
                <span className="absolute inset-0 bg-green-400 rounded-full animate-ping opacity-25"></span>
              </div>
            ) : (
              <MicOff className="w-4 h-4 text-white/30" />
            )}
            <span className={`text-xs font-medium tracking-wide ${statusType === 'error' ? 'text-red-300' : 'text-white/60'}`}>
              {statusMsg || 'Processing…'}
            </span>
          </div>
        )}

        {/* LLM message — persistent until next user speech */}
        {llmMessage && !isProcessing && (
          <div className="glass-message px-7 py-4 max-w-xl text-center anim-drop anim-breathe">
            <p className="text-sm font-medium text-white/90 leading-relaxed">
              {llmMessage}
            </p>
          </div>
        )}

        {/* Live voice transcript */}
        {transcript && !isProcessing && (
          <div className="mt-3 glass-pill px-5 py-1.5 max-w-md text-center">
            <p className="text-[11px] text-white/40 truncate tracking-wider font-medium">
              "{transcript}"
            </p>
          </div>
        )}
      </div>

      {/* ═══════════════════════════════════════════════════════
          SLEEP SCREEN
          ═══════════════════════════════════════════════════════ */}
      {!appActive && !isLoading && (
        <div className="absolute inset-0 bg-black/40 backdrop-blur-sm flex flex-col items-center justify-center z-[150]">
          <h1 className="text-6xl font-black bg-gradient-to-br from-indigo-400 via-purple-500 to-pink-500 bg-clip-text text-transparent drop-shadow-2xl mb-8">
            AR SHOPPING ASST
          </h1>
          <div className="glass-pill flex items-center gap-4 px-8 py-4">
            <Mic className="w-5 h-5 text-white/80 animate-pulse" />
            <p className="text-lg font-light text-white/80 tracking-widest uppercase">
              Say <span className="font-semibold text-purple-300">"Hey Cart"</span> to wake
            </p>
          </div>
          <p className="mt-10 text-xs text-white/35 max-w-sm text-center leading-relaxed font-light">
            Point at an item and say <span className="text-blue-300/60">"I want this"</span> to find it on Amazon & eBay.
          </p>
        </div>
      )}

      {/* ═══════════════════════════════════════════════════════
          PRODUCT RESULTS
          ═══════════════════════════════════════════════════════ */}
      {appActive && rawResults && <ResultsPanels results={rawResults} />}

      {/* ═══════════════════════════════════════════════════════
          BOTTOM HUD — vision tools + tracking status
          ═══════════════════════════════════════════════════════ */}

      {/* Bottom-center HUD: tracking badge + vision tools stacked */}
      <div className="absolute bottom-6 left-1/2 -translate-x-1/2 z-[100] flex flex-col items-center gap-2.5">
        {/* Tracking badge */}
        <div className={`glass-pill flex items-center gap-2.5 px-4 py-2 transition-all duration-500 ${isTracking ? 'glass-pill--success' : ''}`}>
          <div className={`w-2 h-2 rounded-full ${isTracking ? 'bg-green-400 animate-pulse' : 'bg-white/20'}`} />
          <span className={`text-[11px] font-medium tracking-wider ${isTracking ? 'text-green-300/80' : 'text-white/30'}`}>
            {isTracking ? 'Hand Tracked' : 'No Hand Detected'}
          </span>
        </div>

        {/* Vision tools — below tracker */}
        {appActive && (
          <div className="glass-pill flex items-center gap-2 px-4 py-1.5">
            <span className="text-sm">👉</span>
            <span className="text-[10px] text-white/40 font-medium">Point at objects</span>
          </div>
        )}
      </div>

      {/* Hand tracker (invisible) */}
      <div className="hidden">
        <HandTracker onTrackingChange={setIsTracking} videoRef={videoRef} />
      </div>
    </div>
  );
}
