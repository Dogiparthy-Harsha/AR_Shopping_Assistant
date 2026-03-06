# AR Shopping Assistant - Project Context

Welcome to the AR Shopping Assistant project! This document outlines the current state of the application, recent development focus areas, and technical details to help you pick up where the last developer left off. 

## Project Overview

The project is an AR shopping assistant that helps users interact with retail environments and e-commerce items contextually using AR capabilities, voice commands, and hands-free interactions. It consists of:
1. **Frontend**: An iOS application (built with Xcode) using ARKit, and potentially plans for Meta Quest (VR/Passthrough) and Ray-Ban Meta glasses integration.
2. **Backend Engine (`prime-apollo`)**: A Python-based API server that communicates with multimodal AI models and external e-commerce APIs (eBay, Amazon).

## Core Features
1. **Product Search & Analysis**: Captures photos/video of items the user is looking at and queries e-commerce platforms (Amazon, eBay) to display relevant product links and information directly in AR.
2. **Voice & Audio Interface**: Users can trigger searches using voice commands (e.g., "I want this") and the app uses Text-to-Speech (TTS) to read out responses.
3. **Hand tracking for 3D interactions**: In specific scenes, the right hand is used to interact with 3D objects (rotation, scaling, grabbing) while the left hand is specifically dedicated to toggling a "zoom lock" feature.

## Recent Progress & Known Issues

Here is exactly what the previous developer has been working on most recently:

### Frontend / iOS App (`ARShoppingGlasses`)
* **Product Display Bug**: The UI sometimes gets stuck in an "analyzing" state after successfully fetching data from the backend (eBay/Amazon results). Make sure `ProductResultsView` presents the data after resolution.
* **AR Flow Debugging**: 
  * Addressed issues heavily involving voice command triggers failing to process correctly, and text-to-speech playing back improperly.
  * Addressed a bug where the camera session remained active even after capturing and uploading an image.
* **Hand Tracking UI**: Right hand tracks manipulations (grab, scale, rotate), while the left hand functions to consistently debounce/toggle the "zoom lock" exclusively.

### Backend (`prime-apollo`)
* Contains logic to process requests, route queries to external commerce APIs, and format the results.
* Python environment debugging has taken place recently (always run the backend within its active `venv/bin/activate` context, typically using a `zsh` terminal). 

## Roadmap / Future Implementations
* **Meta Smart Glasses Integration**: Significant architectural planning was done to port AR iOS features over to Meta glasses (Ray-ban, Meta Quest) using Meta's XR SDKs and Unity/C# in the future.

## How to Get Started
1. Run the Python backend: 
   ```bash
   cd prime-apollo
   source venv/bin/activate
   # Start the API server using your preferred runner (e.g. uvicorn, python main.py, etc.)
   ```
2. Build the Xcode App: 
   - Open `/Users/harsha/Documents/xcode_arshopping/ARShoppingGlasses/ARShoppingGlasses.xcodeproj` (or `.xcworkspace`).
   - Please ensure the `APIService.swift` (or relevant env file) points to the local or hosted `prime-apollo` API URL.
   - Run via Xcode onto a physical iPhone device for camera/AR testing.
