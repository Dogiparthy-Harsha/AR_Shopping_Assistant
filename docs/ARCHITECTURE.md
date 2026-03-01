# Architecture — AR Shopping Assistant

## System Overview

An AR-powered shopping assistant that uses your live camera feed, voice commands, and AI vision to identify products and find them across eBay and Amazon in real-time.

```mermaid
graph TB
    subgraph Frontend["Frontend — React + Vite :5173"]
        CAM[Camera Feed]
        VOICE[Voice Recognition]
        HAND[Hand Tracker]
        UI[Glassmorphism UI]
    end

    subgraph Backend["Backend — FastAPI :8000"]
        API[api_mcp.py]
        AUTH[JWT Auth]
        RAG[RAG Engine]
        MCP_C[MCP Client]
    end

    subgraph MCP["MCP Agent Servers"]
        RES[Research Agent :8001]
        EBAY[eBay Agent :8002]
        AMZ[Amazon Agent :8003]
    end

    subgraph Data["Data Layer"]
        SQL[(SQLite — Users & Chats)]
        PINE[(Pinecone — Vector Embeddings)]
    end

    subgraph External["External APIs"]
        OR[OpenRouter — Gemini AI]
        SERP[Serper — Web Search]
        EBAY_API[eBay Browse API]
        RAIN[Rainforest API — Amazon]
        OAI[OpenAI — Embeddings]
    end

    CAM -->|Frame capture| API
    VOICE -->|Transcribed text| API
    HAND -.->|Tracking status| UI
    UI -->|HTTP REST| API

    API --> AUTH
    API --> RAG
    API --> MCP_C

    MCP_C -->|MCP Protocol| RES
    MCP_C -->|MCP Protocol| EBAY
    MCP_C -->|MCP Protocol| AMZ

    RES --> SERP
    EBAY --> EBAY_API
    AMZ --> RAIN

    API --> OR
    RAG --> OAI
    RAG --> PINE
    API --> SQL
```

## Request Flow

```mermaid
sequenceDiagram
    participant U as User (Voice + Camera)
    participant FE as Frontend
    participant API as FastAPI Backend
    participant RAG as RAG / Pinecone
    participant AI as Gemini AI
    participant MCP as MCP Agents
    participant EXT as eBay + Amazon APIs

    U->>FE: "Hey Cart" → Wake
    U->>FE: "I want this" → Capture frame
    FE->>API: POST /chat (text + base64 image)

    API->>RAG: Retrieve past search context
    RAG-->>API: Relevant history embeddings

    API->>AI: Prompt with image + context + history
    AI-->>API: "What brand/size do you want?"

    API-->>FE: { response: follow-up question }
    FE->>U: Display glass message bar (persistent)

    U->>FE: "Size 50, any brand" (voice)
    FE->>API: POST /chat (text answer)

    API->>AI: Generates search query
    AI-->>API: FINAL_QUERY: "Sunscreen SPF 50"

    par Search all platforms
        API->>MCP: Research Agent → verify product
        API->>MCP: eBay Agent → search eBay
        API->>MCP: Amazon Agent → search Amazon
    end

    MCP->>EXT: API calls
    EXT-->>MCP: Product results
    MCP-->>API: Combined results

    API->>RAG: Store conversation for future personalization
    API-->>FE: { results: { ebay: [...], amazon: [...] } }
    FE->>U: Display glass product cards
```

## Component Architecture

### Frontend (`frontend/`)

| File | Purpose |
|------|---------|
| `App.jsx` | Main app: camera, voice command handler, glassmorphism result panels |
| `api/visionClaw.js` | HTTP client for backend — frame capture + message sending |
| `hooks/useVoiceCommands.js` | Speech recognition: wake word ("Hey Cart"), capture ("I want this"), general speech |
| `components/HandTracker.jsx` | MediaPipe hand tracking overlay |
| `components/SneakerModel.jsx` | 3D AR model renderer (Three.js) |
| `index.css` | Glassmorphism design system — glass cards, pills, animations |

### Backend (`backend/`)

| File | Purpose |
|------|---------|
| `api_mcp.py` | FastAPI server: `/chat`, `/register`, `/login` endpoints |
| `auth.py` | JWT token generation + bcrypt password hashing |
| `database.py` | SQLite setup via SQLAlchemy |
| `models.py` | User, Conversation, ChatMessage ORM models |
| `embeddings.py` | Pinecone vector storage + OpenAI embedding generation |
| `mcp_client.py` | MCP protocol client — connects to agent servers |
| `agents/search_agents.py` | eBay (Browse API) + Amazon (Rainforest API) search logic |
| `agents/research_agent.py` | Product verification via Serper web search |
| `mcp_servers/research_server.py` | MCP server wrapper for research agent (port 8001) |
| `mcp_servers/ebay_server.py` | MCP server wrapper for eBay search (port 8002) |
| `mcp_servers/amazon_server.py` | MCP server wrapper for Amazon search (port 8003) |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Vite, MediaPipe, Web Speech API |
| UI System | Glassmorphism (backdrop-filter blur, glass cards/pills) |
| Backend | Python, FastAPI, Uvicorn |
| AI | Google Gemini via OpenRouter, OpenAI Embeddings |
| Protocol | Model Context Protocol (MCP) over stdio |
| Databases | SQLite (users/chats), Pinecone (vector embeddings) |
| Auth | JWT + bcrypt |
| Shopping APIs | eBay Browse API, Rainforest API (Amazon), Serper (web search) |

## RAG Pipeline

```mermaid
graph LR
    MSG[User Message] --> EMB[OpenAI Embedding]
    EMB --> STORE[Store in Pinecone]
    
    NEW[New Message] --> QUERY[Query Pinecone]
    QUERY --> CTX[Retrieve Similar Past Messages]
    CTX --> PROMPT[Enhance AI Prompt with Context]
    PROMPT --> AI[Gemini Response]
    AI --> STORE2[Store Response in Pinecone]
```

Each user's data is isolated via `user_id` metadata filtering in Pinecone. The RAG system retrieves context from **past** conversations only (not the current one) to avoid circular references.

## Ports

| Service | Port |
|---------|------|
| Frontend (Vite dev) | 5173 |
| Backend API | 8000 |
| Research Agent | 8001 |
| eBay Agent | 8002 |
| Amazon Agent | 8003 |
