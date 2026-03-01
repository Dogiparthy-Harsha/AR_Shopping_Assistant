import { useEffect, useRef, useCallback } from 'react';
import { Hands } from '@mediapipe/hands';

export default function HandTracker({
    onHandMove,
    onTrackingChange,
    onPinchChange,
    onPositionChange,
    onGrabChange,
    onZoomLockChange,
    videoRef: externalVideoRef
}) {
    const internalVideoRef = useRef(null);
    const videoRef = externalVideoRef || internalVideoRef;
    const canvasRef = useRef(null);
    const handsRef = useRef(null);
    const isInitializedRef = useRef(false);

    // Zoom lock state with debouncing
    const isZoomLockedRef = useRef(false);
    const hadLeftHandRef = useRef(false);
    const leftHandFrameCountRef = useRef(0);
    const FRAMES_TO_CONFIRM = 10;

    // Detect if hand is making a fist
    const detectFist = useCallback((hand) => {
        const fingertips = [8, 12, 16, 20];
        const knuckles = [5, 9, 13, 17];
        let curledFingers = 0;

        for (let i = 0; i < fingertips.length; i++) {
            const tip = hand[fingertips[i]];
            const knuckle = hand[knuckles[i]];
            const wrist = hand[0];

            const tipToWrist = Math.sqrt(Math.pow(tip.x - wrist.x, 2) + Math.pow(tip.y - wrist.y, 2));
            const knuckleToWrist = Math.sqrt(Math.pow(knuckle.x - wrist.x, 2) + Math.pow(knuckle.y - wrist.y, 2));

            if (tipToWrist < knuckleToWrist * 0.9) {
                curledFingers++;
            }
        }

        return curledFingers >= 3;
    }, []);

    // Draw landmarks on canvas
    const drawLandmarks = useCallback((landmarks, handedness, ctx, width, height, pinchDistance, isFist, isZoomLocked) => {
        ctx.clearRect(0, 0, width, height);

        if (!landmarks || landmarks.length === 0) return;

        let hasLeftHand = false;
        let hasRightHand = false;

        landmarks.forEach((hand, handIndex) => {
            // Get handedness (note: MediaPipe returns mirrored, so "Left" in data = right hand visually)
            const label = handedness[handIndex]?.label || 'Right';
            const isRightHand = label === 'Left'; // Mirrored: Left label = Right hand visually

            if (isRightHand) hasRightHand = true;
            else hasLeftHand = true;

            const connections = [
                [0, 1], [1, 2], [2, 3], [3, 4],
                [0, 5], [5, 6], [6, 7], [7, 8],
                [0, 9], [9, 10], [10, 11], [11, 12],
                [0, 13], [13, 14], [14, 15], [15, 16],
                [0, 17], [17, 18], [18, 19], [19, 20],
                [5, 9], [9, 13], [13, 17]
            ];

            // Right hand: purple/green, Left hand: blue (lock indicator)
            const handColor = isRightHand
                ? (isFist ? 'rgba(34, 197, 94, 0.9)' : 'rgba(139, 92, 246, 0.8)')
                : 'rgba(59, 130, 246, 0.9)';

            ctx.strokeStyle = handColor;
            ctx.lineWidth = isRightHand ? (isFist ? 3 : 2) : 2;

            connections.forEach(([start, end]) => {
                const startPoint = hand[start];
                const endPoint = hand[end];
                ctx.beginPath();
                ctx.moveTo(startPoint.x * width, startPoint.y * height);
                ctx.lineTo(endPoint.x * width, endPoint.y * height);
                ctx.stroke();
            });

            // Draw pinch line for right hand only when not in fist mode
            if (isRightHand && !isFist) {
                const thumbTip = hand[4];
                const indexTip = hand[8];
                const isPinching = pinchDistance < 0.08;

                ctx.strokeStyle = isPinching ? '#22c55e' : (isZoomLocked ? '#3b82f6' : '#f97316');
                ctx.lineWidth = 3;
                ctx.setLineDash([5, 5]);
                ctx.beginPath();
                ctx.moveTo(thumbTip.x * width, thumbTip.y * height);
                ctx.lineTo(indexTip.x * width, indexTip.y * height);
                ctx.stroke();
                ctx.setLineDash([]);
            }

            hand.forEach((landmark, index) => {
                const x = landmark.x * width;
                const y = landmark.y * height;
                const isControlPoint = index === 9;
                const isPinchPoint = index === 4 || index === 8;

                ctx.beginPath();
                ctx.arc(x, y, isPinchPoint ? 6 : (isControlPoint ? 8 : 4), 0, 2 * Math.PI);

                if (!isRightHand) {
                    // Left hand - always blue
                    ctx.fillStyle = '#3b82f6';
                    ctx.shadowColor = '#3b82f6';
                    ctx.shadowBlur = 6;
                } else if (isFist) {
                    ctx.fillStyle = '#22c55e';
                    ctx.shadowColor = '#22c55e';
                    ctx.shadowBlur = 6;
                } else if (isControlPoint) {
                    ctx.fillStyle = '#22c55e';
                    ctx.shadowColor = '#22c55e';
                    ctx.shadowBlur = 10;
                } else if (isPinchPoint) {
                    const isPinching = pinchDistance < 0.08;
                    ctx.fillStyle = isPinching ? '#22c55e' : (isZoomLocked ? '#3b82f6' : '#f97316');
                    ctx.shadowColor = isPinching ? '#22c55e' : (isZoomLocked ? '#3b82f6' : '#f97316');
                    ctx.shadowBlur = 8;
                } else {
                    ctx.fillStyle = '#a855f7';
                    ctx.shadowBlur = 0;
                }

                ctx.fill();
            });
        });

        ctx.shadowBlur = 0;

        // Draw status indicators
        let statusY = 20;
        if (isFist) {
            ctx.fillStyle = '#22c55e';
            ctx.font = 'bold 14px sans-serif';
            ctx.fillText('✊ GRAB MODE', 10, statusY);
            statusY += 18;
        }
        if (isZoomLocked) {
            ctx.fillStyle = '#3b82f6';
            ctx.font = 'bold 14px sans-serif';
            ctx.fillText('🔒 ZOOM LOCKED', 10, statusY);
            statusY += 18;
        }
        if (hasLeftHand) {
            ctx.fillStyle = '#3b82f6';
            ctx.font = 'bold 12px sans-serif';
            ctx.fillText('✋ Left hand (lock control)', 10, statusY);
        }
    }, []);

    const onHandMoveRef = useRef(onHandMove);
    const onTrackingChangeRef = useRef(onTrackingChange);
    const onPinchChangeRef = useRef(onPinchChange);
    const onPositionChangeRef = useRef(onPositionChange);
    const onGrabChangeRef = useRef(onGrabChange);
    const onZoomLockChangeRef = useRef(onZoomLockChange);

    useEffect(() => {
        onHandMoveRef.current = onHandMove;
        onTrackingChangeRef.current = onTrackingChange;
        onPinchChangeRef.current = onPinchChange;
        onPositionChangeRef.current = onPositionChange;
        onGrabChangeRef.current = onGrabChange;
        onZoomLockChangeRef.current = onZoomLockChange;
    }, [onHandMove, onTrackingChange, onPinchChange, onPositionChange, onGrabChange, onZoomLockChange]);

    const onResults = useCallback((results) => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        const width = canvas.width;
        const height = canvas.height;

        if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
            const landmarks = results.multiHandLandmarks;
            const handedness = results.multiHandedness || [];

            // Find right and left hands
            let rightHand = null;
            let leftHandPresent = false;

            landmarks.forEach((hand, index) => {
                const label = handedness[index]?.label || 'Right';
                // Note: MediaPipe returns mirrored labels
                // "Left" in data = Right hand visually (your right hand)
                // "Right" in data = Left hand visually (your left hand)
                if (label === 'Left') {
                    rightHand = hand;
                } else {
                    leftHandPresent = true;
                }
            });

            // Handle left hand zoom lock toggle (with debouncing)
            if (leftHandPresent) {
                leftHandFrameCountRef.current++;
                if (leftHandFrameCountRef.current === FRAMES_TO_CONFIRM && !hadLeftHandRef.current) {
                    isZoomLockedRef.current = !isZoomLockedRef.current;
                    if (onZoomLockChangeRef.current) {
                        onZoomLockChangeRef.current(isZoomLockedRef.current);
                    }
                    hadLeftHandRef.current = true;
                }
            } else {
                leftHandFrameCountRef.current = 0;
                hadLeftHandRef.current = false;
            }

            // Only process right hand for object control
            if (rightHand) {
                const controlPoint = rightHand[9];
                const thumbTip = rightHand[4];
                const indexTip = rightHand[8];

                const isFist = detectFist(rightHand);

                const pinchDistance = Math.sqrt(
                    Math.pow(thumbTip.x - indexTip.x, 2) +
                    Math.pow(thumbTip.y - indexTip.y, 2)
                );

                if (onGrabChangeRef.current) {
                    onGrabChangeRef.current(isFist);
                }

                // Position control when fist is closed
                if (isFist && onPositionChangeRef.current) {
                    const posX = -(controlPoint.x - 0.5) * 8;
                    const posY = -(controlPoint.y - 0.5) * 6;
                    onPositionChangeRef.current({ x: posX, y: posY });
                }

                // Rotation control when hand is open
                if (!isFist && onHandMoveRef.current) {
                    const rotationY = (controlPoint.x - 0.5) * Math.PI * 2;
                    const rotationX = (controlPoint.y - 0.5) * Math.PI;
                    onHandMoveRef.current({ x: rotationX, y: rotationY });
                }

                // Scale control - only when NOT locked and not in fist mode
                if (!isFist && !isZoomLockedRef.current) {
                    const minPinch = 0.03;
                    const maxPinch = 0.25;
                    const minScale = 0.4;
                    const maxScale = 1.8;

                    const normalizedPinch = Math.max(0, Math.min(1, (pinchDistance - minPinch) / (maxPinch - minPinch)));
                    const scale = minScale + normalizedPinch * (maxScale - minScale);

                    if (onPinchChangeRef.current) {
                        onPinchChangeRef.current(scale);
                    }
                }

                if (onTrackingChangeRef.current) {
                    onTrackingChangeRef.current(true);
                }

                drawLandmarks(landmarks, handedness, ctx, width, height, pinchDistance, isFist, isZoomLockedRef.current);
            } else {
                // No right hand detected
                drawLandmarks(landmarks, handedness, ctx, width, height, 0, false, isZoomLockedRef.current);
                if (onTrackingChangeRef.current) {
                    onTrackingChangeRef.current(false);
                }
                if (onGrabChangeRef.current) {
                    onGrabChangeRef.current(false);
                }
            }
        } else {
            ctx.clearRect(0, 0, width, height);
            leftHandFrameCountRef.current = 0;
            hadLeftHandRef.current = false;
            if (onTrackingChangeRef.current) {
                onTrackingChangeRef.current(false);
            }
            if (onGrabChangeRef.current) {
                onGrabChangeRef.current(false);
            }
        }
    }, [drawLandmarks, detectFist]);

    useEffect(() => {
        if (isInitializedRef.current) return;

        const video = videoRef.current;
        if (!video) return;

        isInitializedRef.current = true;

        const hands = new Hands({
            locateFile: (file) => {
                return `https://cdn.jsdelivr.net/npm/@mediapipe/hands@0.4.1675469240/${file}`;
            }
        });

        hands.setOptions({
            maxNumHands: 2,
            modelComplexity: 1,
            minDetectionConfidence: 0.5,
            minTrackingConfidence: 0.5,
            selfieMode: false
        });

        hands.onResults(onResults);
        handsRef.current = hands;

        let animationFrameId;
        let isProcessing = false;

        const processFrame = async () => {
            if (handsRef.current && video.readyState >= 2 && !isProcessing) {
                isProcessing = true;
                try {
                    await handsRef.current.send({ image: video });
                } catch (e) { }
                isProcessing = false;
            }
            animationFrameId = requestAnimationFrame(processFrame);
        };

        // If an external video ref is provided, the stream is managed externally (by App.jsx).
        // Just wait for it to be ready, then start processing frames.
        if (externalVideoRef) {
            const waitForVideo = () => {
                if (video.readyState >= 2) {
                    processFrame();
                } else {
                    video.addEventListener('loadeddata', () => processFrame(), { once: true });
                }
            };
            waitForVideo();
        } else {
            // No external ref — manage our own camera
            navigator.mediaDevices.getUserMedia({
                video: { width: 1280, height: 720, facingMode: 'user' }
            }).then((stream) => {
                video.srcObject = stream;
                video.onloadedmetadata = () => {
                    video.play();
                    processFrame();
                };
            }).catch((err) => {
                console.error('Webcam error:', err);
            });
        }

        return () => {
            if (animationFrameId) cancelAnimationFrame(animationFrameId);
            // Only stop tracks if we own the stream
            if (!externalVideoRef && video.srcObject) {
                video.srcObject.getTracks().forEach(track => track.stop());
            }
            if (handsRef.current) {
                handsRef.current.close();
                handsRef.current = null;
            }
            isInitializedRef.current = false;
        };
    }, [onResults, videoRef]);

    return (
        <>
            {!externalVideoRef && <video ref={videoRef} style={{ display: 'none' }} autoPlay playsInline muted />}
            <div className="webcam-container">
                <div className="webcam-label">Hand Tracking</div>
                <canvas ref={canvasRef} className="webcam-canvas" width={320} height={240} />
            </div>
        </>
    );
}
