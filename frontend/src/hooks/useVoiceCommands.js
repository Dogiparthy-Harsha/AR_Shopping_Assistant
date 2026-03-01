import { useState, useEffect, useRef, useCallback } from 'react';

export default function useVoiceCommands() {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [appActive, setAppActive] = useState(false);
  const [lastCommand, setLastCommand] = useState(null);

  const recognitionRef = useRef(null);
  const restartTimeoutRef = useRef(null);

  // Use refs for values accessed inside recognition callbacks to avoid stale closures
  const appActiveRef = useRef(false);
  const isListeningRef = useRef(false);

  // Keep refs in sync with state
  useEffect(() => { appActiveRef.current = appActive; }, [appActive]);
  useEffect(() => { isListeningRef.current = isListening; }, [isListening]);

  const scheduleRestart = useCallback(() => {
    if (restartTimeoutRef.current) clearTimeout(restartTimeoutRef.current);
    restartTimeoutRef.current = setTimeout(() => {
      if (recognitionRef.current && !isListeningRef.current) {
        try {
          recognitionRef.current.start();
        } catch (err) {
          console.error("Error restarting recognition", err);
        }
      }
    }, 500);
  }, []);

  const processCommand = useCallback((command) => {
    console.log("Heard:", command);

    const wakeWords = ['hey cart', 'hey kurt', 'cake cart', 'hey kat', 'hey god',
      'hair cut', 'haircut', 'hey caught', 'hey karth', 'hey card'];
    const isWakeWord = wakeWords.some(word => command.includes(word));

    const captureCommands = ['i want this', 'check this item', 'check this out',
      'what is this', 'i want this item'];

    const isCaptureCommand = captureCommands.some(phrase => command.includes(phrase));

    if (isWakeWord) {
      console.log(">>> WAKE WORD DETECTED");
      setAppActive(true);
      appActiveRef.current = true;
      setLastCommand({ type: 'wake', text: command, timestamp: Date.now() });
    } else if (isCaptureCommand) {
      // Always fire capture if we heard a capture phrase — 
      // appActive might be stale in the closure, so use the ref
      console.log(">>> CAPTURE COMMAND DETECTED, appActive:", appActiveRef.current);
      setLastCommand({ type: 'capture', text: command, timestamp: Date.now() });
    } else if (appActiveRef.current && command.length > 2) {
      console.log(">>> GENERAL SPEECH");
      setLastCommand({ type: 'general', text: command, timestamp: Date.now() });
    }
  }, []);

  // Initialize speech recognition ONCE
  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      console.error("Speech Recognition API is not supported in this browser.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = 'en-US';

    recognition.onstart = () => {
      setIsListening(true);
      isListeningRef.current = true;
      console.log('Voice recognition started.');
    };

    recognition.onresult = (event) => {
      let currentInterim = '';
      let finalTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript;
        } else {
          currentInterim += event.results[i][0].transcript;
        }
      }

      setTranscript(currentInterim || finalTranscript);

      if (finalTranscript) {
        processCommand(finalTranscript.toLowerCase().trim());
      }
    };

    recognition.onerror = (event) => {
      console.error('Speech recognition error:', event.error);
      if (event.error !== 'aborted') {
        scheduleRestart();
      }
    };

    recognition.onend = () => {
      setIsListening(false);
      isListeningRef.current = false;
      // Always restart to keep listening
      scheduleRestart();
    };

    recognitionRef.current = recognition;

    // Start immediately
    try {
      recognition.start();
    } catch (err) {
      console.error("Error starting recognition", err);
    }

    return () => {
      if (restartTimeoutRef.current) clearTimeout(restartTimeoutRef.current);
      recognition.stop();
    };
  }, [processCommand, scheduleRestart]);


  // Text to speech helper
  const speak = useCallback((text) => {
    console.log(">>> SPEAKING:", text);

    // Stop listening while speaking to avoid feedback loop
    if (recognitionRef.current && isListeningRef.current) {
      recognitionRef.current.stop();
    }

    // Chrome bug workaround: cancel any pending/stuck speech
    window.speechSynthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);

    // Pick a good English voice
    const voices = window.speechSynthesis.getVoices();
    const englishVoice = voices.find(v => v.lang.startsWith('en-') && v.default)
      || voices.find(v => v.lang.startsWith('en-'));
    if (englishVoice) {
      utterance.voice = englishVoice;
    }

    utterance.volume = 1;
    utterance.rate = 1;

    utterance.onend = () => {
      console.log(">>> SPEECH ENDED, resuming listening");
      scheduleRestart();
    };

    utterance.onerror = (e) => {
      console.error("Speech Synthesis Error:", e);
      scheduleRestart();
    };

    window.speechSynthesis.speak(utterance);
  }, [scheduleRestart]);

  return {
    isListening,
    transcript,
    appActive,
    lastCommand,
    startListening: scheduleRestart,
    stopListening: () => {
      setAppActive(false);
      appActiveRef.current = false;
      if (recognitionRef.current) recognitionRef.current.stop();
      if (restartTimeoutRef.current) clearTimeout(restartTimeoutRef.current);
    },
    speak
  };
}
